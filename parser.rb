# -*- coding: utf-8 -*-

require 'mail'
require 'exifr'
require 'nkf'
require 'RMagick'
load 'localwiki_client.rb'
load 'api_settings.rb'

def upload_image_and_edit_page(args, page_hash, filepath, width, height, body)

  return if body.nil? and filepath.nil?
  if filepath
    page_slug = page_hash["slug"]
    file = LocalWikiFile.new args
    filename = File::basename(filepath)
    file.upload(filepath, filename, page_slug)
  end
  page = LocalWikiPage.new args
  content = page_hash["content"]
  if filepath
    content << <<EOS
<p>
<span class="image_frame image_frame_border">
<img src="_files/#{filename}" style="width: #{width}px; height: #{height}px;" />
</span></p>
EOS
  end
  if body
    content += body
  end
  page_obj = {
    "content" => content
  }
  title = page_hash["name"]
  page.update(title, page_obj)
  
end

timestamp = Time.now.strftime("%Y-%m-%d_%H_%M_%S")
temp_mail = File.join(File.expand_path(File.dirname(__FILE__)), "file", "eml", timestamp + ".eml")
f = File.open(temp_mail, "w", 0644)
while line = STDIN.gets
  f.write line
end
f.close

mail = Mail.read(temp_mail)

args_for_apikey = get_setting

emailaddress = mail.from[0].to_s

search_users_obj = Array.new
search_users_obj << "email"
search_users_obj << "contains"
search_users_obj << emailaddress
search_users_objs = Array.new
search_users_objs << search_users_obj

users_with_key = LocalWikiUsersWithKey.new args_for_apikey
search_result = users_with_key.search_with_auth(search_users_objs)
if search_result.nil? or search_result["objects"].blank?
  puts "can't find user"
  exit
end
user_obj = search_result["objects"][0]
username = user_obj["username"]
api_key_path = user_obj["api_key"]
if api_key_path.blank?
  puts "not exist api key"
  exit
end
api_key_client = LocalWikiApiKey.new args_for_apikey
search_result_api_key = api_key_client.get(api_key_path)
if search_result_api_key.nil?
  puts "can't get api key"
  exit
end
api_key = search_result_api_key["key"]
args = {
  :base_url => args_for_apikey[:base_url],
  :user_name => username,
  :api_key => api_key
}

title = nil
body = nil
filepath = nil
latitude = nil
longitude = nil
upload_flag = false
has_location = false

mail.attachments.each do |attachment|
  if (attachment.content_type.start_with?('image/jpeg'))
    test = File.join(File.expand_path(File.dirname(__FILE__)), "file", "jpeg", timestamp + ".jpg")
    begin
      File.open(test, "w+b", 0644) { |f| f.write attachment.body.decoded }
      exif = EXIFR::JPEG.new(test)
      upload_flag = true
      filepath = test
      unless exif.gps_latitude.nil? && exif.gps_longitude.nil?
        latitude = (exif.gps_latitude[0] + exif.gps_latitude[1] / 60 + exif.gps_latitude[2] / 3600).to_f
        longitude = (exif.gps_longitude[0] + exif.gps_longitude[1] / 60 + exif.gps_longitude[2] / 3600).to_f
        has_location = true
      end
    rescue Exception => e
      puts "Unable to save data for #{test} because #{e.message}"
    end
  end
  break if upload_flag
end

#exit unless upload_flag

title = mail.subject

unless mail.parts.blank?
  mail.parts.each do |part|
    if part.multipart?
      # multipart/alternative
      text_part = part.text_part
      # iso-2022-jp fix(for japanese)
      if (text_part.content_type.match('2022'))
        body = NKF.nkf('-w', text_part.body.decoded)
      else
        body = text_part.body.decoded
      end
    elsif part.content_type.start_with?('text/plain')
      if part.content_type.match('2022')
        body = NKF.nkf('-w', part.body.decoded)
      else
        body = part.body.decoded
      end
    end
    break if body
  end
else 
  if mail.content_type.start_with?('text/plain')
    if mail.content_type.match('2022')
      body = NKF.nkf('-w', mail.body.decoded)
    else
      body = mail.body.decoded
    end
  end
end
exit unless body

if filepath
  # auto orient
  img = Magick::ImageList.new(filepath)
  img.auto_orient!
  img.write(filepath)
  
  # size
  width = img.columns
  height = img.rows
  if width > 300
    width = width / 2
    height = height / 2
  end
end

#1. page.exist? -> false:2 true:3
page = LocalWikiPage.new args

body = "<p>" + body + "</p>"

page_hash = page.exist?(title)

if page_hash.nil?
  #2.1 page.create
  page_obj = {
    "content" => body,
    "name" => title
  }
  unless page.create(page_obj)
    puts "can't create page"
    exit
  end
  page_hash = page.exist?(title)
  page_api_location = page_hash["resource_uri"]
  
  #2.2 upload image -> upload_image_and_edit_page

  #2.3 create map
  if has_location
    map_obj = {
      "geom" => {
        "geometries" => [
                         {
                           "coordinates" => [ longitude, latitude ], 
                           "type" => "Point"
                         }
                        ],
        "type" => "GeometryCollection"
      },
      "page" => page_api_location
    }
    map = LocalWikiMap.new args
    map.create(map_obj)
  end

  #2.4 edit page
  if upload_flag
    upload_image_and_edit_page(args, page_hash, filepath, width, height, nil)
  end

else

  #3.1 upload image
  #3.2 edit page
  upload_image_and_edit_page(args, page_hash, filepath, width, height, body)
end

