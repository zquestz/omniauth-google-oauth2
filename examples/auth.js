// Basic hybrid auth example following the pattern at:
// https://developers.google.com/api-client-library/javascript/features/authentication#Authexample
jQuery(function() {
  return $.ajax({
    url: 'https://apis.google.com/js/client:plus.js?onload=gpAsyncInit',
    dataType: 'script',
    cache: true
  });
});

window.gpAsyncInit = function() {
  gapi.auth.authorize({
    immediate: true,
    response_type: 'code',
    cookie_policy: 'single_host_origin',
    client_id: 'YOUR_CLIENT_ID',
    scope: 'email profile'
  }, function(response) {
    return;
  });
  $('.googleplus-login').click(function(e) {
    e.preventDefault();
    gapi.auth.authorize({
      immediate: false,
      response_type: 'code',
      cookie_policy: 'single_host_origin',
      client_id: 'YOUR_CLIENT_ID',
      scope: 'email profile'
    }, function(response) {
      if (response && !response.error) {
        // google authentication succeed, now post data to server. 
        jQuery.ajax({type: 'POST', url: "/auth/google_oauth2/callback", 
data: response,
          success: function(data) {
            // response from server
          }
        });
      } else {
        // google authentication failed
      }
    });
  });
};
