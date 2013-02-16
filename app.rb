require "rubygems"
require "httpclient"
require "nokogiri"
require "feedzirra"

MINGLE_HOST="localhost"
MINGLE_PORT="4001"
API_USERNAME="admin"
API_PASSWORD="p"

STATUS_PROP_NAME = "Status"
STATUS_PROP_VALUE = "To Do"

PROGRAM = "animal_husbandry"
TARGET_PROJECT_ID = "cow_farm"

CLIENT = HTTPClient.new

def watch_feed
  log "Checking for updates..."
  feed = Feedzirra::Feed.fetch_and_parse("http://#{API_USERNAME}:#{API_PASSWORD}@#{MINGLE_HOST}:#{MINGLE_PORT}/api/v2/programs/#{PROGRAM}/plan/feeds/events.xml")
  last_entry_updated_at = Time.now.to_i
  while(true) do
    updated_feed = Feedzirra::Feed.update(feed)
    new_entries = updated_feed.entries.select do |entry|
      entry.updated.to_i > last_entry_updated_at
    end

    if new_entries.empty?
      log "Parsed feed. No new entries found"
    else
      log "Parsed feed. #{new_entries.length } new entries found."
      last_entry_updated_at = new_entries.first.updated.to_i
      new_entries.each do |entry|
       process_entry(entry)
      end
    end
    sleep(3)
  end
end

def create_card_for(entry)
  CLIENT.set_auth entry.url, API_USERNAME, API_PASSWORD
  obj_xml = CLIENT.get(entry.url).body
  obj_name = Nokogiri::XML(obj_xml).xpath("//name").children.first.text
  cards_url = "http://#{MINGLE_HOST}:#{MINGLE_PORT}/api/v2/projects/#{TARGET_PROJECT_ID}/cards.xml"
  log "Trying to create card with name '#{obj_name}'"
  CLIENT.set_auth cards_url, API_USERNAME, API_PASSWORD
  resp = CLIENT.post cards_url, {
    "card[name]" => obj_name,
    "card[properties][][name]" => STATUS_PROP_NAME,
    "card[properties][][value]" => STATUS_PROP_VALUE,
    "card[card_type_name]" => "Card"
  }
  if resp.status.to_i == 201
    log "Card '#{obj_name}' created successfully."
  else
    log "Card '#{obj_name}' could not be created."
  end
end

def process_entry(entry)
  if entry.title =~ /Objective planned/
    log "Objective create event. Trying to create card"
    create_card_for(entry)
  else
    log "Update event. Won't create new card"
  end
end

def log(msg)
  p "#{Time.now} #{msg}"
end

watch_feed
