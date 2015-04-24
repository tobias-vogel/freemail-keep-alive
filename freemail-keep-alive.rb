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

  imapHostname = ""
  imapPort = ""
  xmldoc.elements.each("/clientConfig/emailProvider/incomingServer[@type='imap' and socketType/text() = 'SSL']") do |incomingServer|
    imapHostname = incomingServer.get_elements("hostname").first.text
    imapPort = incomingServer.get_elements("port").first.text
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
    "imapHostname" => imapHostname,
    "imapPort" => imapPort,
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

puts "Forwarding all new emails to #{finalEmailAddress}."

# read list of accounts
CSV.read("configuration/accounts.tsv", {:col_sep => "\t"}).each do |row|
  if row.size == 0 or row[0].start_with?("#")
    # ignore empty or comment lines
    next
  end

  puts

  email = row[0]
  password = row[1]
  puts "Logging into the email account of ""#{email}""…"

  service = email[/(?<=@).*/]

  ispSettingsCache[service] = lookupService service if ispSettingsCache[service].nil?
  settings = ispSettingsCache[service]

  Mail.defaults do
#    retriever_method :pop3,
#      :address    => settings["popHostname"],
#      :port       => settings["popPort"],
#      :user_name  => email,
#      :password   => password,
#      :enable_ssl => true

    retriever_method :imap,
      :address    => settings["imapHostname"],
      :port       => settings["imapPort"],
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


#  mails = Mail.all
  mails = Mail.find(keys: ["NOT", "SEEN"])
  numberOfEmails = mails.size
  puts "…finding #{mails.size} new (unread) email(s) in total."

  mails.each_with_index do |mail, index|
    puts "Email #{index + 1}/#{numberOfEmails}: #{mail.subject}"

    puts "Forwarding this email to #{finalEmailAddress}…"
    mail.to = finalEmailAddress
    mail.deliver!
  end
end

puts

puts "Finished."
