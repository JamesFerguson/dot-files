# monkey patch Object to allow calls to get_html which returns html of some page in your site
#
# cf http://snipplr.com/view/37506/fetch-a-page-from-your-site-from-console/
#   & http://stackoverflow.com/questions/123494/whats-your-favourite-irb-trick

@reminders << %Q{
get_html('/login') => "<html of login page>"
}

class Object
  # e.g. get_html('/login') => "<html of login page>"
  def get_html(options = {})
    url = app.url_for(options)
    app.get url
    puts app.html_document.root.to_s
  end
end