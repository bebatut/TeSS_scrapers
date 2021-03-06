#!/usr/bin/env ruby

require 'open-uri'
require 'nokogiri'
require 'tess_api_client'

$root_url = 'http://www.ebi.ac.uk'
$owner_org = 'european-bioinformatics-institute-ebi'
$lessons = {}
$debug = ScraperConfig.debug?


def parse_data(page)
  doc = Nokogiri::HTML(open($root_url + page))

  #first = doc.css('div.item-list').search('li')
  first = doc.css('li.views-row')
  first.each do |f|
    titles = f.css('div.views-field-title').css('span.field-content').search('a')
    desc = f.css('div.views-field-field-course-desc-value').css('div.field-content').search('p')
    topics = f.css('div.views-field-tid').css('span.field-content').search('a')

    #puts "TITLES: #{titles.css('a')[0]['href']}, #{titles.text}"
    #puts "DESC: #{desc.text}"
    #puts "TOPICS: #{topics.collect{|t| t.text }}"

    href = titles.css('a')[0]['href']
    $lessons[href] = {}
    $lessons[href]['description'] = desc.text.strip
    $lessons[href]['text'] = titles.css('a')[0].text
    topic_text =  topics.collect{|t| t.text }
    if !topic_text.empty?
      #$lessons[href]['topics'] = topic_text.map{|t| {'name' => t.gsub(/[^0-9a-z ]/i, ' ')} } # Replaces extract_keywords
      $lessons[href]['topics'] = topic_text.collect{|t| t.gsub(/[^0-9a-z ]/i, ' ') } # Replaces extract_keywords
    end                                                                             # Non-alphanumeric purged

  end

end


def last_page_number
  # This method needs to be updated to find the actual final page.
  return 2
end


# Scrape all the pages.
first_page = '/training/online/course-list'
parse_data(first_page)
1.upto(last_page_number) do |num|
    page = first_page + '?page=' + num.to_s
    puts "Scraping page: #{num.to_s}"
    parse_data(page)
end

cp = ContentProvider.new({
                             title: "European Bioinformatics Institute (EBI)", #name
                             url: "http://www.ebi.ac.uk", #url
                             image_url: "http://www.ebi.ac.uk/miriam/static/main/img/EBI_logo.png", #logo
                             description: "EMBL-EBI provides freely available data from life science experiments, performs basic research in computational biology and offers an extensive user training programme, supporting researchers in academia and industry.", #description
                             content_provider_type: ContentProvider::PROVIDER_TYPE[:ORGANISATION],
                             node: Node::NODE_NAMES[:'EMBL-EBI']
                         })

cp = Uploader.create_or_update_content_provider(cp)

# Create the new record
$lessons.each_key do |key|

  material = Material.new({title: $lessons[key]['text'],
                          url: $root_url + key,
                          short_description: "#{$lessons[key]['text']} from #{$root_url + key}.",
                          doi: nil,
                          remote_updated_date: Time.now,
                          remote_created_date: $lessons[key]['last_modified'],
                          content_provider_id: cp['id'],
                          scientific_topic: $lessons[key]['topics'],
                          keywords: $lessons[key]['topics']})

  Uploader.create_or_update_material(material)

end
