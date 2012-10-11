# -*- coding: utf-8 -*-

require 'mail'
require 'exifr'
require 'tempfile'
require 'nkf'
require 'RMagick'
load 'localwiki_client.rb'
load 'api_settings.rb'

def upload_image_and_edit_page(args, page_hash, filepath, width, height)

  page_slug = page_hash["slug"]
  file = LocalWikiFile.new args
  filename = File::basename(filepath)
  file.upload(filepath, filename, page_slug)

  page = LocalWikiPage.new args
  content = <<EOS
#{page_hash["content"]}
<p>
<span class="image_frame image_frame_border">
<img src="_files/#{filename}" style="width: #{width}px; height: #{height}px;" />
</span></p>
EOS
  page_obj = {
    "content" => content
  }
  title = page_hash["name"]
  page.update(title, page_obj)
  
end

temp_mail = Tempfile.new(["mail", "eml"], File.join(File.expand_path(File.dirname(__FILE__)), "file", "eml"))
temp_mail.close
f = File.open(temp_mail, "w", 0644)
while line = STDIN.gets
  f.write line
end
f.close

mail = Mail.read(temp_mail)

exit unless mail.multipart?

title = nil
body = nil
filepath = nil
latitude = nil
longitude = nil
upload_flag = false

mail.attachments.each do |attachment|
  if (attachment.content_type.start_with?('image/jpeg'))
    test = Tempfile.new(["photo", ".jpg"], File.join(File.expand_path(File.dirname(__FILE__)), "file", "eml", "jpeg"))
    test.close
    begin
      File.open(test.path, "w+b", 0644) { |f| f.write attachment.body.decoded }
      exif = EXIFR::JPEG.new(test.path)
      latitude = (exif.gps_latitude[0] + exif.gps_latitude[1] / 60 + exif.gps_latitude[2] / 3600).to_f
      longitude = (exif.gps_longitude[0] + exif.gps_longitude[1] / 60 + exif.gps_longitude[2] / 3600).to_f
      upload_flag = true
      filepath = test.path
    rescue Exception => e
      puts "Unable to save data for #{test.path} because #{e.message}"
    end
  end
  break if upload_flag
end

exit unless upload_flag

title = mail.subject

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

exit unless body

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

args = get_setting

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

  #2.4 edit page
  upload_image_and_edit_page(args, page_hash, filepath, width, height)

else

  #3.1 upload image
  #3.2 edit page
  upload_image_and_edit_page(args, page_hash, filepath, width, height)

end

