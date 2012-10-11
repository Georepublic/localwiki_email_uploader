# -*- coding: utf-8 -*-
require 'rest_client'
require 'json'
require 'cgi'

class LocalWikiClientBase
  
  def initialize args
    @base_url = args[:base_url] or raise ArgumentError, "must need :base_url"
    @user_name = args[:user_name]
    @api_key = args[:api_key]
  end
  
  def api_path
  end
  
  
  def headers
    _headers = {}
    _authorization_header = authorization_header
    unless _authorization_header.nil?
      _headers[:authorization] = _authorization_header
    end
    _headers[:content_type] = :json
    _headers[:accept] = :json
    return _headers
  end

  def exist?(page_or_id)
    begin
      response = RestClient.get @base_url + api_path + CGI.escape(page_or_id), headers
      if response.code == 200
        return JSON.parse(response.to_str)
      end
    rescue => e
      puts e
    end
    return nil
  end

  def create(obj)
    raise RuntimeError, "must set user_name and api_key" unless can_post?
    begin
      response = RestClient.post @base_url + api_path, JSON.dump(obj), headers
      if response.code == 201
        return true
      end
    rescue => e
      puts "Unable create because #{e.message}"
    end
    return false
  end

  def update(page_or_id, obj)
    raise RuntimeError, "must set user_name and api_key" unless can_post?
    begin
      response = RestClient.put @base_url + api_path + CGI.escape(page_or_id), JSON.dump(obj), headers
      if response.code == 204
        return true
      end
    rescue => e
      puts "Unable update because #{e.message}"
    end
    return false
  end
    

  def delete(page_or_id)
    raise RuntimeError, "must set user_name and api_key" unless can_post?
    begin
      response = RestClient.delete @base_url + api_path + CGI.escape(page_or_id), headers
      if response.code == 204
        return true
      end
    rescue => e
      puts "Unable delete because #{e.message}"
    end
    return false
  end

  private
  def can_post?
    return false if @user_name.blank? or @api_key.blank?
    return true
  end

  def authorization_header
    return nil unless can_post?
    return "ApiKey #{@user_name}:#{@api_key}"
  end

end

class LocalWikiPage < LocalWikiClientBase

  def api_path
    "/api/page/"
  end

end

class LocalWikiFile < LocalWikiClientBase

  def api_path
    "/api/file/"
  end
  
  def upload(file_path, file_name, slug)
    
    begin
      response = RestClient.post @base_url + api_path, {:file => File.new(file_path, 'rb'), :name => file_name, :slug => slug}, headers
    rescue => e
      puts e
    end
  end
end

class LocalWikiMap < LocalWikiClientBase
  
  def api_path
    "/api/map/"
  end

end
