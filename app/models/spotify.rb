require 'rspotify'

class Spot
  
  def search(keyword)
    artist = RSpotify::Artist.search("#{keyword}").first 
    artist.albums.first.images[2]["url"]
  end
  
end