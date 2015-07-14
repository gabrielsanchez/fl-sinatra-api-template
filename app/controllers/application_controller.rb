require './config/environment'
require './app/models/giph.rb'
require './app/models/spotify.rb'

class ApplicationController < Sinatra::Base

  configure do
    set :public_folder, 'public'
    set :views, 'app/views'
  end

  get '/' do
    erb :index
  end
  
  post '/results' do
    spot = Spot.new
    @photo = spot.search(params[:artist])
    erb :res
  end

end
