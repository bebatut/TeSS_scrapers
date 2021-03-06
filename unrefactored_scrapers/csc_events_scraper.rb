#!/usr/bin/env ruby

require 'open-uri'
require 'nokogiri'
require 'tess_api_client'
require 'geocoder'


$root_url = 'https://www.csc.fi/web/training/'
$owner_org = 'csc'
$events = {}
$debug = ScraperConfig.debug?

def parse_data()

    if $debug
      puts 'Opening local file.'
      begin
        f = File.open("html/csc_events.html")
        doc = Nokogiri::HTML(f)
        f.close
      rescue
        puts "Failed to open csc_events.html file."
      end
    else
      puts "Opening: #{$root_url}"
      doc = Nokogiri::HTML(open($root_url))
    end

    doc.css('div.csc-article').each do |article|
      categories = article.search('.koulutus-category').collect {|x| x.text.strip}.reject(&:empty?)
      header = article.search('h3 > a')[0]
      link = header['href']
      title = header.text
      description = article.search('.article-summary')[0].text

      $events[link] = {'title' => title,
                       'description' => description,
                       'categories' => categories,
                       'keywords' => categories}
    end
end


##################################################
# Main body of the script below, functions above #
##################################################

cp = ContentProvider.new({
                             title: "CSC - IT Center for Science",
                             url: "https://www.csc.fi",
                             image_url: "https://www.csc.fi/documents/10180/161914/CSC_2012_LOGO_RGB_72dpi.jpg/c65ddc42-63fc-44da-8d0f-9f88c54779d7?t=1411391121769",
                             description: "CSC - IT Center for Science Ltd. is a non-profit, state-owned company administered by the Finnish Ministry of Education and Culture. CSC maintains and develops the state-owned centralised IT infrastructure and uses it to provide nationwide IT services for research, libraries, archives, museums and culture as well as information, education and research management.
    CSC has the task of promoting the operational framework of Finnish research, education, culture and administration. As a non-profit, government organisation, it is our duty to foster exemplary transparency, honesty and responsibility. Trust is the foundation of CSC's success. Customers, suppliers, owners and personnel alike must feel certain that we will fulfil our commitments and promises in an ethically sustainable manner.
    CSC has offices in Espoo's Keilaniemi and in the Renforsin Ranta business park in Kajaani.",
                             content_provider_type: ContentProvider::PROVIDER_TYPE[:ORGANISATION],
                             node: Node::NODE_NAMES[:FI],
                         })
#cp = Uploader.create_or_update_content_provider(cp)

# Actually run the code here...
parse_data

$events.each_key do |key|
  lat,lon = nil # Can't seem to get these out of the Google maps URL
  start_date, end_date, venue = nil

  if $debug
    next unless $events[key]['title'] == 'Python in High-Performance Computing'
    puts 'Opening local file.'
    begin
      f = File.open("html/csc_event_detail.html")
      newpage = Nokogiri::HTML(f)
      f.close
    rescue
      puts "Failed to open csc_events.html file."
    end
  else
    newpage = Nokogiri::HTML(open(key))
  end

  newpage.search('table > tr').each do |row|
    fieldname = row.css('td')[0].text.strip
    if fieldname == 'Date:'
      datefield = row.css('td')[1].text.strip
      start_date,end_date = datefield.split(/ - /)
    elsif fieldname == 'Location details:'
      venue = row.css('td')[1].text.strip
      # Strip out certain long strings we don't need in the venue.
      venue.gsub!(/^The event is organised at the /,"")
      venue.gsub!(/^The event is organised at /,"")
      venue.gsub!(/ The best way to reach us is by public transportation; more detailed travel tips(\)?) are available.$/,"")
    end
  end

  loc = Geocoder.search(venue)
  if !loc.empty?
    lat = loc[0].data['geometry']['location']['lat']
    lon = loc[0].data['geometry']['location']['lng']
  end

#  :external_id, :title,:subtitle,:url,:provider,:field,:description,:keywords,:category,
#      :start,:end,:sponsor,:venue,:city,:county, :country,:postcode,:latitude,:longitude,:id,
#      :content_provider_id

  event = Event.new({
      content_provider_id: cp['id'],
      title: $events[key]['title'],
      url: key,
      description: $events[key]['description'],
      start_date: start_date,
      end_date: end_date,
      venue: venue,
      latitude: lat,
      longitude: lon
  })
  #puts event.inspect
  Uploader.create_or_update_event(event)

end


