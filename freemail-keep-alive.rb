# encoding: utf-8
# The above line is important for Ruby to properly read in the file (otherwise, some encoding errors arise).

# http://www.rubydoc.info/gems/mail/frames
# https://github.com/mikel/mail

# installation:
# gem install mail (for mail)
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
  popHostname = ""
  popPort = ""
  xmldoc.elements.each("/clientConfig/emailProvider/incomingServer[@type='pop3' and socketType/text() = 'SSL']") do |incomingServer|
    popHostname = incomingServer.get_elements("hostname").first.text
    popPort = incomingServer.get_elements("port").first.text
    break
  end

  smtpHostname = ""
  smtpPort = ""
  xmldoc.elements.each("/clientConfig/emailProvider/outgoingServer[@type='smtp' and socketType/text() = 'STARTTLS']") do |outgoingServer|
    smtpHostname = outgoingServer.get_elements("hostname").first.text
    smtpPort = outgoingServer.get_elements("port").first.text
    break
  end

  return {
    "popHostname" => popHostname,
    "popPort" => popPort,
    "smtpHostname" => smtpHostname,
    "smtpPort" => smtpPort
  }
end


# let's go

# determine ruby version
mainVersion, subVersion, subsubVersion = RUBY_VERSION.split(".")
if mainVersion.to_i < 2 and subVersion.to_i < 9 then
  puts "ruby version is too old (expected 1.9, found #{RUBY_VERSION}); Wrong ruby interpreter used?"
  exit
end

if ARGV.size != 1 or ARGV.first[/\w+@\w+\.\w+/].nil? then
  puts "no email address provided to forward found emails to"
  exit
end

finalEmailAddress = ARGV.first

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

    delivery_method :smtp,
      :address    => settings["smtpHostname"],
      :port       => settings["smtpPort"],
      :user_name  => email,
      :password   => password,
      :enable_ssl => true
  end


  puts "Logging into the email account of ""#{email}""…"
  mails = Mail.all
  numberOfEmails = mails.size
  puts "…finding #{mails.size} emails in total."

  mails.each_with_index do |mail, index|
    puts "mail #{index + 1}/#{numberOfEmails}: #{mail.subject} mit attachment:#{mail.attachments.size}"

    # forward the email to the provided final email address
    mail.to = finalEmailAddress
    mail.deliver!
  end
end

puts "Finished."
