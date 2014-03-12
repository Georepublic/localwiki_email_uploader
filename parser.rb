# -*- coding: utf-8 -*-

require 'mail'
require 'exifr'
require 'nkf'
require 'RMagick'
load 'localwiki_client.rb'
load 'api_settings.rb'
require 'cgi'
require 'unicode_utils'

def unescape_list(tags)
  ret = Array.new
  tags.each do |tag|
    ret << CGI.unescape(tag)
  end
  return ret
end

# Convert title to LocalWiki slug format.
def slugify(title)
    slug = UnicodeUtils.nfkd(title)
    slug.gsub(/(\w|\s|-|.|,|'|"|\/|!|@|$|%|&|\*|\(|\))/, "")
    slug = slug.downcase
    return slug
end

def new_or_add_tag(args, page_name, page_uri, tag_uri, tag_name)
  page_tags = LocalWikiPageTags.new args
  page_tags_hash = page_tags.exist?(page_name)
  new_tag_uri = "/api/tag/" + tag_name
  if page_tags_hash.nil?
    page_tags_obj = {
      "page" => page_uri,
      "tags" => [new_tag_uri]
    }
    puts page_tags_obj
    unless page_tags.create(page_tags_obj)
      puts "can't create page_tag"
      return nil
    end
  else
    unless page_tags_hash["tags"].include?(tag_uri)
      page_tags_hash["tags"] = unescape_list(page_tags_hash["tags"])
      page_tags_hash["tags"] << new_tag_uri
      unless page_tags.update(page_name, page_tags_hash)
        puts "can't update page_tag"
        return nil
      end
    end
  end
  return true
end  

def upload_image(args, page_slug, filepath)

  return if filepath.nil?
  file = LocalWikiFile.new args
  filename = File::basename(filepath)
  file.upload(filepath, filename, page_slug, get_setting[:region])

  return filename
  
end

def append_image(content, filename, width, height)
  had_content_already = !(content.nil?)
  content << <<EOS
<p>
<span class="image_frame image_frame_border">
<img src="_files/#{filename}" style="width: #{width}px; height: #{height}px;" />
</span></p>
EOS
  return content

end

def add_tag(page, page_hash, tag_slug)
    return if tag_slug.nil?
    obj = {
        "tags" => page_hash["tags"]
    }
    obj["tags"] << tag_slug
    page.patch(page_hash["url"], obj)
end

def upload_image_and_edit_page(args, page_hash, filepath, width, height, body)

  return if body.nil? and filepath.nil?
  if filepath
    page_slug = page_hash["slug"]
    file = LocalWikiFile.new args
    filename = File::basename(filepath)
    file.upload(filepath, filename, page_slug, get_setting[:region])
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
    content += ("<hr />" + body)
  end
  page_obj = page_hash
  page_obj["content"] = content
  title = page_hash["name"]
  page.update(page_hash["url"], page_obj)
  
end

timestamp = Time.now.strftime("%Y-%m-%d_%H_%M_%S")
temp_mail = File.join(File.expand_path(File.dirname(__FILE__)), "file", "eml", timestamp + ".eml")
f = File.open(temp_mail, "w", 0644)
while line = STDIN.gets
  f.write line
end
f.close

mail = Mail.read(temp_mail)

title = mail.subject
exit if title.blank?

args_for_apikey = get_setting

emailaddress = mail.from[0].to_s

search_users_obj = Array.new
search_users_obj << "email"
search_users_obj << "contains"
search_users_obj << emailaddress
search_users_objs = Array.new
search_users_objs << search_users_obj

args = {
  :base_url => get_setting[:base_url],
  :api_key => get_setting[:api_key],
  :region => get_setting[:region]
}

body = nil
filepath = nil
latitude = nil
longitude = nil
upload_flag = false
has_location = false

mail.attachments.each do |attachment|
  content_type = attachment.content_type.downcase
  if (content_type.start_with?('image/jpeg') or content_type.start_with?('image/jpg'))
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

tag_slug = get_setting[:tag_slug]
page_slug = slugify(title)

#1. upload the image, if present.
if upload_flag
  filename = upload_image(args, page_slug, filepath)
end

#2. page.exist? -> false:3 true:4
page = LocalWikiPage.new args
body = body.gsub(/(\r\n|[\r\n])/, "</p><p>\n")
body = "<p>" + body + "</p>"

page_hash = page.exist?(title)

if page_hash.nil?
  #3.1 page.create, with appended image
  content = append_image(body, filename, width, height)
  page_obj = {
    "content" => content,
    "name" => title,
    "region" => get_setting[:region]
  }
  puts page_obj
  unless page.create(page_obj)
    puts "can't create page"
    exit
  end
  page_hash = page.exist?(title)
  page_api_location = page_hash["url"]
  
  #3.3 create map
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
      "page" => page_api_location,
      "region" => get_setting[:region]
    }
    map = LocalWikiMap.new args
    map.create(map_obj)
  end

else
  #4.1 update the existing page content with the appended image and appended body
  page_obj = {
    "content" => append_image(page_hash["content"], filename, width, height),
    "name" => title,
    "region" => get_setting[:region]
  }
  if body
    page_obj["content"] += ('<hr/>' + body)
  end
  page.update(page_hash["url"], page_obj)

end

#5 Add tag, if present
add_tag(page, page_hash, tag_slug)
