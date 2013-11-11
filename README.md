# OmniAuth Google OAuth2 Strategy

Strategy to authenticate with Google via OAuth2 in OmniAuth.

Get your API key at: https://code.google.com/apis/console/

For more details, read the Google docs: https://developers.google.com/accounts/docs/OAuth2

## Installation

Add to your `Gemfile`:

```ruby
gem "omniauth-google-oauth2"
```

Then `bundle install`.

## Usage

Here's an example for adding the middleware to a Rails app in `config/initializers/omniauth.rb`:

```ruby
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, ENV["GOOGLE_KEY"], ENV["GOOGLE_SECRET"]
end
```

You can now access the OmniAuth Google OAuth2 URL: `/auth/google_oauth2`

For more examples please check out `examples/omni_auth.rb`

## Configuration

You can configure several options, which you pass in to the `provider` method via a hash:

* `scope`: A comma-separated list of permissions you want to request from the user. See the [Google OAuth 2.0 Playground](https://developers.google.com/oauthplayground/) for a full list of available permissions. Caveats:
  * The `userinfo.email` and `userinfo.profile` scopes are used by default. By defining your own `scope`, you override these defaults. If you need these scopes, don't forget to add them yourself!
  * Scopes starting with `https://www.googleapis.com/auth/` do not need that prefix specified. So while you can use the smaller scope `books` since that permission starts with the mentioned prefix, you should use the full scope URL `https://docs.google.com/feeds/` to access a user's docs, for example.
* `prompt`: A space-delimited list of string values that determines whether the user is re-prompted for authentication and/or consent. Possible values are:
  * `none`: No authentication or consent pages will be displayed; it will return an error if the user is not already authenticated and has not pre-configured consent for the requested scopes. This can be used as a method to check for existing authentication and/or consent.
  * `consent`: The user will always be prompted for consent, even if he has previously allowed access a given set of scopes.
  * `select_account`: The user will always be prompted to select a user account. This allows a user who has multiple current account sessions to select one amongst them.

  If no value is specified, the user only sees the authentication page if he is not logged in and only sees the consent page the first time he authorizes a given set of scopes.

* `image_aspect_ratio`: The shape of the user's profile picture. Possible values are:
  * `original`: Picture maintains its original aspect ratio.
  * `square`: Picture presents equal width and height.

  Defaults to `original`.

* `image_size`: The size of the user's profile picture. The image returned will have width equal to the given value and variable height, according to the `image_aspect_ratio` chosen. Additionally, a picture with specific width and height can be requested by setting this option to a hash with `width` and `height` as keys. If only `width` or `height` is specified, a picture whose width or height is closest to the requested size and requested aspect ratio will be returned. Defaults to the original width and height of the picture.

* `name`: The name of the strategy. The default name is `google_oauth2` but it can be changed to any value, for example `google`. The OmniAuth URL will thus change to `/auth/google` and the `provider` key in the auth hash will then return `google`.

* `access_type`: Defaults to `offline`, so a refresh token is sent to be used when the user is not present at the browser. Can be set to `online`. Note that if you need a refresh token, google requires you to also to specify the option `prompt: 'consent'`, which is not a default.

Here's an example of a possible configuration where the strategy name is changed, the user is asked for extra permissions, the user is always prompted to select his account when logging in and the user's profile picture is returned as a thumbnail:

```ruby
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, ENV["GOOGLE_KEY"], ENV["GOOGLE_SECRET"],
    {
      :name => "google",
      :scope => "userinfo.email, userinfo.profile, plus.me, http://gdata.youtube.com",
      :prompt => "select_account",
      :image_aspect_ratio => "square",
      :image_size => 50
    }
end
```

## Auth Hash

Here's an example of an authentication hash available in the callback by accessing `request.env["omniauth.auth"]`:

```ruby
{
    :provider => "google_oauth2",
    :uid => "123456789",
    :info => {
        :name => "John Doe",
        :email => "john@company_name.com",
        :first_name => "John",
        :last_name => "Doe",
        :image => "https://lh3.googleusercontent.com/url/photo.jpg"
    },
    :credentials => {
        :token => "token",
        :refresh_token => "another_token",
        :expires_at => 1354920555,
        :expires => true
    },
    :extra => {
        :raw_info => {
            :id => "123456789",
            :email => "user@domain.example.com",
            :verified_email => true,
            :name => "John Doe",
            :given_name => "John",
            :family_name => "Doe",
            :link => "https://plus.google.com/123456789",
            :picture => "https://lh3.googleusercontent.com/url/photo.jpg",
            :gender => "male",
            :birthday => "0000-06-25",
            :locale => "en",
            :hd => "company_name.com"
        }
    }
}
```

### Devise

For devise, you should also make sure you have an OmniAuth callback controller setup

```ruby
class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
      # You need to implement the method below in your model (e.g. app/models/user.rb)
      @user = User.find_for_google_oauth2(request.env["omniauth.auth"], current_user)

      if @user.persisted?
        flash[:notice] = I18n.t "devise.omniauth_callbacks.success", :kind => "Google"
        sign_in_and_redirect @user, :event => :authentication
      else
        session["devise.google_data"] = request.env["omniauth.auth"]
        redirect_to new_user_registration_url
      end
  end
end
```

and bind to or create the user

```ruby
def self.find_for_google_oauth2(access_token, signed_in_resource=nil)
    data = access_token.info
    user = User.where(:email => data["email"]).first

    unless user
        user = User.create(name: data["name"],
             email: data["email"],
             password: Devise.friendly_token[0,20]
            )
    end
    user
end
```
Detailed example at https://github.com/plataformatec/devise/wiki/OmniAuth:-Overview#google-oauth2-example

## Build Status
[![Build Status](https://travis-ci.org/zquestz/omniauth-google-oauth2.png)](https://travis-ci.org/zquestz/omniauth-google-oauth2)


## License

Copyright (c) 2013 by Josh Ellithorpe

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
