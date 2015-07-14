module RSpotify

  # @attr [String] birthdate       The user's date-of-birth. This field is only available when the current user has granted access to the *user-read-birthdate* scope.
  # @attr [String] country         The country of the user, as set in the user's account profile. An {http://en.wikipedia.org/wiki/ISO_3166-1_alpha-2 ISO 3166-1 alpha-2 country code}. This field is only available when the current user has granted access to the *user-read-private* scope.
  # @attr [Hash]   credentials     The credentials generated for the user with OAuth. Includes access token, token type, token expiration time and refresh token. This field is only available when the current user has granted access to any scope.
  # @attr [String] display_name    The name displayed on the user's profile. This field is only available when the current user has granted access to the *user-read-private* scope.
  # @attr [String] email           The user's email address. This field is only available when the current user has granted access to the *user-read-email* scope.
  # @attr [Hash]   followers       Information about the followers of the user
  # @attr [Array]  images          The user's profile image. This field is only available when the current user has granted access to the *user-read-private* scope.
  # @attr [String] product         The user's Spotify subscription level: "premium", "free", etc. This field is only available when the current user has granted access to the *user-read-private* scope.
  # @attr [Hash]   tracks_added_at A hash containing the date and time each track was saved by the user. Note: the hash is filled and updated only when {#saved_tracks} is used.
  class User < Base

    # Returns User object with id provided
    #
    # @param id [String]
    # @return [User]
    #
    # @example
    #           user = RSpotify::User.find('wizzler')
    #           user.class #=> RSpotify::User
    #           user.id    #=> "wizzler"
    def self.find(id)
      super(id, 'user')
    end

    # Spotify does not support search for users.
    def self.search(*)
      warn 'Spotify API does not support search for users'
      false
    end

    def self.refresh_token(user_id)
      request_body = {
        grant_type: 'refresh_token',
        refresh_token: @@users_credentials[user_id]['refresh_token']
      }
      response = RestClient.post(TOKEN_URI, request_body, RSpotify.send(:auth_header))
      json = JSON.parse(response)
      @@users_credentials[user_id]['token'] = json['access_token']
    end
    private_class_method :refresh_token

    def self.oauth_header(user_id)
      {
        'Authorization' => "Bearer #{@@users_credentials[user_id]['token']}",
        'Content-Type'  => 'application/json'
      }
    end
    private_class_method :oauth_header

    def self.oauth_send(user_id, verb, path, *params)
      RSpotify.send(:send_request, verb, path, *params)
    rescue RestClient::Unauthorized => e
      raise e if e.response !~ /access token expired/
      refresh_token(user_id)
      params[-1] = oauth_header(user_id)
      RSpotify.send(:send_request, verb, path, *params)
    end
    private_class_method :oauth_header

    RSpotify::VERBS.each do |verb|
      define_singleton_method "oauth_#{verb}" do |user_id, path, *params|
        params << oauth_header(user_id)
        oauth_send(user_id, verb, path, *params)
      end
    end

    def initialize(options = {})
      credentials = options['credentials']
      options     = options['info'] if options['info']

      @birthdate    ||= options['birthdate']
      @country      ||= options['country']
      @display_name ||= options['display_name']
      @email        ||= options['email']
      @followers    ||= options['followers']
      @images       ||= options['images']
      @product      ||= options['product']

      super(options)

      if credentials
        @@users_credentials ||= {}
        @@users_credentials[@id] = credentials
        @credentials = @@users_credentials[@id]
      end
    end

    # Creates a playlist in user's Spotify account. This method is only available when the current
    # user has granted access to the *playlist-modify-public* and *playlist-modify-private* scopes.
    #
    # @param name [String] The name for the new playlist
    # @param public [Boolean] Whether the playlist is public or private. Default: true
    # @return [Playlist]
    #
    # @example
    #           user.create_playlist!('my-first-playlist')
    #           user.playlists.last.name   #=> "my-first-playlist"
    #           user.playlists.last.public #=> true
    #
    #           playlist = user.create_playlist!('my-second-playlist', public: false)
    #           playlist.name   #=> "my-second-playlist"
    #           playlist.public #=> false
    def create_playlist!(name, public: true)
      url = "users/#{@id}/playlists"
      request_data = { name: name, public: public }.to_json
      Playlist.new User.oauth_post(@id, url, request_data)
    end

    # Add the current user as a follower of one or more artists, other Spotify users or a playlist. Following artists or users require the *user-follow-modify*
    # scope. Following a playlist publicly requires the *playlist-modify-public* scope; following it privately requires the *playlist-modify-private* scope.
    #
    # @note Scopes you provide for playlists determine only whether the current user can themselves follow the playlist publicly or privately (i.e. show others what they are following), not whether the playlist itself is public or private.
    #
    # @param followed [Artist, Array<Artist>, User, Array<User>, Playlist] The artists, users or playlist to follow
    # @param public [Boolean] If true the playlist will be included in user's public playlists, if false it will remain private.
    # @return [Artist, Array<Artist>, User, Array<User>, Playlist]
    #
    # @example
    #           artists = RSpotify::Artist.search('John')
    #           user.follow(artists)
    #
    #           playlist = RSpotify::Playlist.search('Movie').first
    #           user.follow(playlist, public: false)
    def follow(followed, public: true)
      if followed.is_a? Array
        ids = followed.map(&:id).join(',')
        type = followed.first.type
      else
        ids = followed.id
        type = followed.type
      end

      if type == 'playlist'
        request_body = { public: public }
        url = "users/#{followed.owner.id}/playlists/#{followed.id}/followers"
      else
        request_body = {}
        url = "me/following?type=#{type}&ids=#{ids}"
      end

      User.oauth_put(@id, url, request_body.to_json)
      followed
    end

    # Check if the current user is following one or more artists or other Spotify users. This method
    # is only available when the current user has granted access to the *user-follow-read* scope.
    #
    # @param followed [Artist, Array<Artist>, User, Array<User>] The users or artists to check
    # @return [Array<Boolean>]
    #
    # @example
    #           artists = RSpotify::Artist.search('John')
    #           user.follows?(artists) #=> [true, false, true...]
    def follows?(followed)
      if followed.is_a? Array
        ids = followed.map(&:id).join(',')
        type = followed.first.type
      else
        ids = followed.id
        type = followed.type
      end

      url = "me/following/contains?type=#{type}&ids=#{ids}"
      User.oauth_get(@id, url)
    end

    # Returns all playlists from user
    #
    # @param limit  [Integer] Maximum number of playlists to return. Maximum: 50. Minimum: 1. Default: 20.
    # @param offset [Integer] The index of the first playlist to return. Use with limit to get the next set of playlists. Default: 0.
    # @return [Array<Playlist>]
    #
    # @example
    #           playlists = user.playlists
    #           playlists.class       #=> Array
    #           playlists.first.class #=> RSpotify::Playlist
    #           playlists.first.name  #=> "Movie Soundtrack Masterpieces"
    def playlists(limit: 20, offset: 0)
      url = "users/#{@id}/playlists?limit=#{limit}&offset=#{offset}"
      json = RSpotify.resolve_auth_request(@id, url)
      json['items'].map { |i| Playlist.new i }
    end

    # Remove tracks from the user’s “Your Music” library.
    #
    # @param tracks [Array<Track>] The tracks to remove. Maximum: 50.
    # @return [Array<Track>] The tracks removed.
    #
    # @example
    #           tracks = user.saved_tracks
    #
    #           user.saved_tracks.size #=> 20
    #           user.remove_tracks!(tracks)
    #           user.saved_tracks.size #=> 0
    def remove_tracks!(tracks)
      tracks_ids = tracks.map(&:id)
      url = "me/tracks?ids=#{tracks_ids.join ','}"
      User.oauth_delete(@id, url)
      tracks
    end

    # Save tracks to the user’s “Your Music” library.
    #
    # @param tracks [Array<Track>] The tracks to save. Maximum: 100.
    # @return [Array<Track>] The tracks saved.
    #
    # @example
    #           tracks = RSpotify::Track.search('Know')
    #
    #           user.saved_tracks.size #=> 0
    #           user.save_tracks!(tracks)
    #           user.saved_tracks.size #=> 20
    def save_tracks!(tracks)
      tracks_ids = tracks.map(&:id)
      url = "me/tracks"
      request_body = tracks_ids.inspect
      User.oauth_put(@id, url, request_body)
      tracks
    end

    # Returns the tracks saved in the Spotify user’s “Your Music” library
    #
    # @param limit  [Integer] Maximum number of tracks to return. Maximum: 50. Minimum: 1. Default: 20.
    # @param offset [Integer] The index of the first track to return. Use with limit to get the next set of tracks. Default: 0.
    # @return [Array<Track>]
    #
    # @example
    #           tracks = user.saved_tracks
    #           tracks.size       #=> 20
    #           tracks.first.name #=> "Do I Wanna Know?"
    def saved_tracks(limit: 20, offset: 0)
      url = "me/tracks?limit=#{limit}&offset=#{offset}"
      json = User.oauth_get(@id, url)

      tracks = json['items'].select { |i| i['track'] }
      @tracks_added_at = hash_for(tracks, 'added_at') do |added_at|
        Time.parse added_at
      end

      tracks.map { |t| Track.new t['track'] }
    end

    # Check if tracks are already saved in the Spotify user’s “Your Music” library
    #
    # @param tracks [Array<Track>] The tracks to check. Maximum: 50.
    # @return [Array<Boolean>] Array of booleans, in the same order in which the tracks were specified.
    #
    # @example
    #           tracks = RSpotify::Track.search('Know')
    #           user.saved_tracks?(tracks) #=> [true, false, true...]
    def saved_tracks?(tracks)
      tracks_ids = tracks.map(&:id)
      url = "me/tracks/contains?ids=#{tracks_ids.join ','}"
      User.oauth_get(@id, url)
    end

    # Returns a hash containing all user attributes
    def to_hash
      pairs = instance_variables.map do |var|
        [var.to_s.delete('@'), instance_variable_get(var)]
      end
      Hash[pairs]
    end

    # Remove the current user as a follower of one or more artists, other Spotify users or a playlist. Unfollowing artists or users require the *user-follow-modify* scope.
    # Unfollowing a publicly followed playlist requires the *playlist-modify-public* scope; unfollowing a privately followed playlist requires the *playlist-modify-private* scope.
    #
    # @note Note that the scopes you provide for playlists relate only to whether the current user is following the playlist publicly or privately (i.e. showing others what they are following), not whether the playlist itself is public or private.
    #
    # @param unfollowed [Artist, Array<Artist>, User, Array<User>, Playlist] The artists, users or playlist to unfollow
    # @return [Artist, Array<Artist>, User, Array<User>, Playlist]
    #
    # @example
    #           artists = RSpotify::Artist.search('John')
    #           user.unfollow(artists)
    #
    #           playlist = RSpotify::Playlist.search('Movie').first
    #           user.unfollow(playlist)
    def unfollow(unfollowed)
      if unfollowed.is_a? Array
        ids = unfollowed.map(&:id).join(',')
        type = unfollowed.first.type
      else
        ids = unfollowed.id
        type = unfollowed.type
      end

      url = if type == 'playlist'
        "users/#{unfollowed.owner.id}/playlists/#{unfollowed.id}/followers"
      else
        "me/following?type=#{type}&ids=#{ids}"
      end

      User.oauth_delete(@id, url)
      unfollowed
    end
  end
end
