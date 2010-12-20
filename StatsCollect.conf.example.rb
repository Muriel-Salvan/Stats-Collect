{
  # Configuration for Backends
  :Backends => {
    'MySQL' => {
      :DBHost => 'localhost',
      :DBUser => 'mydbuser',
      :DBPassword => '*****',
      :DBName => 'mydb',
    },
    'Terminal' => {}
  },

  # Configuration for Notifiers
  :Notifiers => {
    'SendMail' => {
      :SMTP => {
        :address => "mail.myhost.com",
        :port => 25,
        :domain => 'mail.myhost.com',
        :user_name => 'smtpuser',
        :password => '*****',
        :authentication => nil,
        :enable_starttls_auto => false
      },
      # The From field
      :From => 'MailOriginator@myhost.com',
      # To who the notifications are sent
      :To => 'mail@host.com'
    },
    'None' => {}
  },

  # Configuration for Locations
  :Locations => {
    'MySpace' => {
      :LoginEMail => 'MySpaceLogin',
      :LoginPassword => '****',
      # This is the last part of profile URL
      :MySpaceName => 'myspace_user',
      # List the blogs IDs. They can be taken from their respective URL.
      :BlogsID => [
        123456789,
        234567891,
        345678912
      ]
    },
    'Facebook' => {
      :LoginEMail => 'FacebookLogin',
      :LoginPassword => '*****'
    },
    'FacebookArtist' => {
      :LoginEMail => 'FacebookLogin',
      :LoginPassword => '*****',
      # URL of the page (after the /pages sub-directory) to fetch stats from
      :PageID => 'ArtistName/123456789012345'
    },
    'ReverbNation' => {
      :LoginEMail => 'ReverbNationLogin',
      :LoginPassword => '*****'
    },
    'AddThis' => {
      :Login => 'AddThisLogin',
      :Password => '*****',
      # List of objects for which we retrieve the AddThis stats
      :Objects => [
        'www.myhost.com'
      ]
    },
    'FacebookLike' => {
      # List of objects for which we retrieve the Facebook likes
      :Objects => [
        'www.myhost.com'
      ]
    },
    'Tweets' => {
      # List of objects for which we retrieve the tweets
      :Objects => [
        'www.myhost.com'
      ]
    },
    'Twitter' => {
      :Name => 'TwitterID'
    },
    'GoogleSearch' => {
      # List of objects for which we will query Google search
      :Objects => [
        'GoogleSearchString'
      ]
    },
  }
}