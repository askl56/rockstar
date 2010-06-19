require 'digest/md5'

# exception definitions
class BadAuthError < StandardError; end
class BannedError < StandardError; end
class BadTimeError < StandardError; end
module Scrobbler
  
  # Token Authentification
  #
  # 1. Step: open http://www.last.fm/api/auth/?api_key={YOUR_API_KEY}&amp;cb={YOUR_RETURN_URL}
  # 2. Step: if the user excepts, lastfm will redirect to YOUR_RETURN_URL?token=TOKEN
  # 3. Get the token and call 
  #     new Scrobbler::Auth(token).session 
  #    with that token. 
  # 4. Store the session.key and session.username returned. The session.key will not
  #    expire. It is save to store it into your database.
  # 5. Use this token to authentificate with this class :
  #     auth = TokenAuth.initialize({:username => 'chunky', :token => 'bacon'})
  #     auth.handshake!
  # 
  class TokenAuth
    # you should read last.fm/api/submissions#handshake

    attr_accessor :user, :token, :client_id, :client_ver
    attr_reader :status, :session_id, :now_playing_url, :submission_url

    def initialize(args = {})
      @user = args[:username] # last.fm user
      @token = args[:token] # last.fm token
      @api_key = args[:api_key] # last.fm api key
      @secret = args[:secret] # last.fm secret
      @client_id = 'rbs' # Client ID assigned by last.fm; Don't change this!
      @client_ver = Scrobbler::Version

      raise ArgumentError, 'Missing required argument' if @user.blank? || @token.blank? || @api_key.blank? || @secret.blank?

      @connection = REST::Connection.new(Scrobbler::AUTH_URL)
    end

    def handshake!
      timestamp = Time.now.to_i.to_s
      auth = Digest::MD5.hexdigest("#{Scrobbler.lastfm_api_secret}#{timestamp}")

      query = { :hs => 'true',
                :p => AUTH_VER,
                :c => @client_id,
                :v => @client_ver,
                :u => @user,
                :t => timestamp,
                :a => auth,
                :api_key=>Scrobbler.lastfm_api_key,
                :sk => @token }
      result = @connection.get('/', query)

      @status = result.split(/\n/)[0]
      case @status
      when /OK/
        @session_id, @now_playing_url, @submission_url = result.split(/\n/)[1,3]
      when /BANNED/
        raise BannedError # something is wrong with the gem, check for an update
      when /BADAUTH/
        raise BadAuthError # invalid user/password
      when /FAILED/
        raise RequestFailedError, @status
      when /BADTIME/
        raise BadTimeError # system time is way off
      else
        raise RequestFailedError
      end  
    end
  end
end