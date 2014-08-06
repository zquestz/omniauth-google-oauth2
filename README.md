# OmniAuth Google OAuth2 Strategy

Strategy to authenticate with Google via OAuth2 in OmniAuth.

Get your API key at: https://code.google.com/apis/console/  Note the Client ID and the Client Secret.

**Note**: You must enable the "Contacts API" and "Google+ API" via the Google API console. Otherwise, you will receive an `OAuth2::Error` stating that access is not configured when you attempt to authenticate.

For more details, read the Google docs: https://developers.google.com/accounts/docs/OAuth2

## Installation

Add to your `Gemfile`:

```ruby
gem "omniauth-google-oauth2"
```

Then `bundle install`.

## Google API Setup

* Go to 'https://console.developers.google.com'
* Select your project.
* Click 'APIs & auth'
* Make sure "Contacts API" and "Google+ API" are on.
* Go to Consent Screen, and provide a 'PRODUCT NAME'
* Wait 10 minutes for changes to take effect.

## Usage

Here's an example for adding the middleware to a Rails app in `config/initializers/omniauth.rb`:

```ruby
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, ENV["GOOGLE_CLIENT_ID"], ENV["GOOGLE_CLIENT_SECRET"]
end
```

You can now access the OmniAuth Google OAuth2 URL: `/auth/google_oauth2`

For more examples please check out `examples/omni_auth.rb`

NOTE: While developing your application, if you change the scope in the initializer you will need to restart your app server. Remember that 'email' and 'profile' scopes are required!

## Configuration

You can configure several options, which you pass in to the `provider` method via a hash:

* `scope`: A comma-separated list of permissions you want to request from the user. See the [Google OAuth 2.0 Playground](https://developers.google.com/oauthplayground/) for a full list of available permissions. Caveats:
  * The `email` and `profile` scopes are used by default. By defining your own `scope`, you override these defaults. If you need these scopes, don't forget to add them yourself!
  * Scopes starting with `https://www.googleapis.com/auth/` do not need that prefix specified. So while you can use the smaller scope `books` since that permission starts with the mentioned prefix, you should use the full scope URL `https://docs.google.com/feeds/` to access a user's docs, for example.
* `approval_prompt`: Indicates whether the user should be re-prompted for consent. Possible values are:
  * `auto`: User should only see the consent page for a given set of scopes the first time through the sequence.
  * `force`: User sees a consent page even if they previously gave consent to your application for a given set of scopes.

  Defaults to `auto`.

* `image_aspect_ratio`: The shape of the user's profile picture. Possible values are:
  * `original`: Picture maintains its original aspect ratio.
  * `square`: Picture presents equal width and height.

  Defaults to `original`.

* `image_size`: The size of the user's profile picture. The image returned will have width equal to the given value and variable height, according to the `image_aspect_ratio` chosen. Additionally, a picture with specific width and height can be requested by setting this option to a hash with `width` and `height` as keys. If only `width` or `height` is specified, a picture whose width or height is closest to the requested size and requested aspect ratio will be returned. Defaults to the original width and height of the picture.

* `name`: The name of the strategy. The default name is `google_oauth2` but it can be changed to any value, for example `google`. The OmniAuth URL will thus change to `/auth/google` and the `provider` key in the auth hash will then return `google`.

* `access_type`: Defaults to `offline`, so a refresh token is sent to be used when the user is not present at the browser. Can be set to `online`. Note that if you need a refresh token, google requires you to also to specify the option `prompt: 'consent'`, which is not a default.

* `login_hint`: When your app knows which user it is trying to authenticate, it can provide this parameter as a hint to the authentication server. Passing this hint suppresses the account chooser and either pre-fill the email box on the sign-in form, or select the proper session (if the user is using multiple sign-in), which can help you avoid problems that occur if your app logs in the wrong user account. The value can be either an email address or the sub string, which is equivalent to the user's Google+ ID.

* `include_granted_scopes`: If this is provided with the value true, and the authorization request is granted, the authorization will include any previous authorizations granted to this user/application combination for other scopes. See Google's [Incremental Autorization](https://developers.google.com/accounts/docs/OAuth2WebServer#incrementalAuth) for additional details.

Here's an example of a possible configuration where the strategy name is changed, the user is asked for extra permissions, the user is always prompted to select his account when logging in and the user's profile picture is returned as a thumbnail:

```ruby
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, ENV["GOOGLE_CLIENT_ID"], ENV["GOOGLE_CLIENT_SECRET"],
    {
      :name => "google",
      :scope => "email, profile, plus.me, http://gdata.youtube.com",
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
            :sub => "123456789",
            :email => "user@domain.example.com",
            :email_verified => true,
            :name => "John Doe",
            :given_name => "John",
            :family_name => "Doe",
            :profile => "https://plus.google.com/123456789",
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

    # Uncomment the section below if you want users to be created if they don't exist
    # unless user
    #     user = User.create(name: data["name"],
    #        email: data["email"],
    #        password: Devise.friendly_token[0,20]
    #     )
    # end
    user
end
```
Detailed example at https://github.com/plataformatec/devise/wiki/OmniAuth:-Overview#google-oauth2-example

### One-time Code Flow (Hybrid Authentication)

Google describes the One-time Code Flow [here](https://developers.google.com/+/web/signin/server-side-flow).  This hybrid authentication flow has significant functional and security advantages over a pure server-side or pure client-side flow.  The following steps occur in this flow:

1. The client (web browser) authenticates the user directly via Google's JS API.  During this process assorted modals may be rendered by Google.
2. On successful authentication, Google returns a one-time use code, which requires the Google client secret (which is only available server-side).
3. Using a AJAX request, the code is POSTed to the Omniauth Google OAuth2 callback.
4. The Omniauth Google OAuth2 gem will validate the code via a server-side request to Google.  If the code is valid, then Google will return an access token and, if this is the first time this user is authenticating against this application, a refresh token.  Both of these should be stored on the server.  The response to the AJAX request indicates the success or failure of this process.

This flow is immune to replay attacks, and conveys no useful information to a man in the middle.

The omniauth-google-oauth2 gem supports this mode of operation out of the box.  Implementors simply need to add the appropriate JavaScript to their web page, and they can take advantage of this flow.  An example JavaScript snippet follows.

```javascript
jQuery(function() {
  return $.ajax({
    url: 'https://apis.google.com/js/client:plus.js?onload=gpAsyncInit',
    dataType: 'script',
    cache: true
  });
});

window.gpAsyncInit = function() {
  $('.googleplus-login').click(function(e) {
    e.preventDefault();
    gapi.auth.authorize({
      immediate: true,
      response_type: 'code',
      cookie_policy: 'single_host_origin',
      client_id: '000000000000.apps.googleusercontent.com',
      scope: 'email profile'
    }, function(response) {
      if (response && !response.error) {
        // google authentication succeed, now post data to server and handle data securely
        jQuery.ajax({type: 'POST', url: "/auth/google_oauth2/callback", dataType: 'json', data: response,
          success: function(json) {
            // response from server
          }
        });
      } else {
        // google authentication failed
      }
    });
  });
};
```


## Build Status
[![Build Status](https://travis-ci.org/zquestz/omniauth-google-oauth2.png)](https://travis-ci.org/zquestz/omniauth-google-oauth2)


## License

Copyright (c) 2013 by Josh Ellithorpe

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
