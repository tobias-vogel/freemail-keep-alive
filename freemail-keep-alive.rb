# http://www.rubydoc.info/gems/mail/frames
# https://github.com/mikel/mail

# installation:
# gem install mail (for mail)
# #gem install nokogiri
# gem install httpclient (for proper https)


# some functions

def lookupService(service)
  # look up settings in thunderbird's ISP database
  # for example, https://autoconfig.thunderbird.net/v1.1/freenet.de

  filename = "cache/#{service}.xml"
  if (!File.exists? filename) then
    puts "Email settings for service ""#{service}"" are retrieved…"
    uri = "https://autoconfig.thunderbird.net/v1.1/#{service}"
    response = HTTPClient.new.get(uri)
    raise IOError, "#{uri} did not return a 200" unless response.status_code == 200
    xml = response.content
    File.open(filename, "w") { |file| file.write(xml) }
  end

  xml = File.open(filename).read
  xmldoc = REXML::Document.new xml
  xmldoc.elements.each("/clientConfig/emailProvider/incomingServer[@type='pop3' and socketType/text() = 'SSL']") do |incomingServer|
  popHostname = incomingServer.get_elements("hostname").first.text
  popPort = incomingServer.get_elements("port").first.text
  return {
    "popHostname" => popHostname,
    "popPort" => popPort
  }
  end
end


# let's go

# determine ruby version
mainVersion, subVersion, subsubVersion = RUBY_VERSION.split(".")
if mainVersion.to_i < 2 and subVersion.to_i < 9 then
  puts "ruby version is too old (expected 1.9, found #{RUBY_VERSION}); Wrong ruby interpreter used?"
  exit
end

require 'mail'
require 'csv'
require 'rexml/document'
require 'httpclient'


ispSettingsCache = {}

puts "Initialized."

# read list of accounts
CSV.read("configuration/accounts.tsv", {:col_sep => "\t"})[1..-1].each do |row|
  email = row[0]
  password = row[1]
  puts "Processing account ""#{email}""…"

  service = email[/(?<=@).*/]

  ispSettingsCache[service] = lookupService service if ispSettingsCache[service].nil?
  settings = ispSettingsCache[service]

  Mail.defaults do
    retriever_method :pop3,
      :address    => settings["popHostname"],
      :port       => settings["popPort"],
      :user_name  => email,
      :password   => password,
      :enable_ssl => true
  end
  
  puts "Logging into the email account of ""#{email}""…"
  mails = Mail.all
  
  puts "…finding #{mails.length} emails in total."

end

puts "Finished."