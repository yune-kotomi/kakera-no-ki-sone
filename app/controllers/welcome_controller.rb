class WelcomeController < ApplicationController
  def index
    @token = GoogleToken.where(:token_id => session.id).first
  end

  def installed
  end
end
