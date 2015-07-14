require 'json'
require 'net/http'

class Giph

  def search(keyword)
    result = get_api_response("http://api.giphy.com/v1/gifs/search?q=#{keyword}&api_key=dc6zaTOxFJmzC")
    result["data"].collect{|gif| gif["images"]["original"]["url"]}
  end
  
  def get_api_response(endpoint) 
    uri = URI.parse(URI.encode(endpoint))
    response = Net::HTTP.get(uri)
    JSON.parse(response)
  end
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
#   def search(keywords)
#     #if there are multiple keywords this creates a string of keywords connected by +
#     query = keywords.split(/,| /).inject("") { |string, keyword| string + "+#{keyword}" }
#     #applies that query string in an api call to the search endpoint
#     response = get_api_response("http://api.giphy.com/v1/gifs/search?q=#{query}&rating=pg&api_key=dc6zaTOxFJmzC")
#     #iterates through the response hash and collects the image url for each gif (25 gifs are returned by default)
#     response["data"].collect { |gif| gif["images"]["original"]["url"] }
#   end
  
#   def get_api_response(endpoint)
#     uri = URI.parse(URI.encode(endpoint))
#     api_response = Net::HTTP.get(uri)
#     JSON.parse(api_response)
#   end
  
end