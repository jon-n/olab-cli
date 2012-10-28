# Jon's Script for pulling OpinionLab comments
# created 10/27/2012

require 'rubygems'
require 'typhoeus'	# for HTTP requests - overkill?
require 'nokogiri'	# for parsing XML
require 'optparse'	# for parsing command line options
require 'date'		# for DateTime stuff

# TODO: let people use environment variables so they don't always have to pass options

# parse the different options to determine what date range and login info to make the request with
options = {}
OptionParser.new do |opts|
	
	# -s	start date	(required, for now)
	# -e 	end date	(required, for now)
	# -u	username	(required, for now)
	# -p	password	(required, for now)
	
	opts.banner = "Usage: olab.rb [options]"
	opts.on("-s", "--start [START DATE]", "Start Date") do |s|
		options[:start_date] = s
	end
	
	opts.on("-e", "--end [END DATE]", "End Date") do |e|
		options[:end_date] = e
	end
	
	opts.on("-u", "--user [USERNAME]", "User Name") do |u|
		options[:username] = u
	end
	
	opts.on("-p", "--pass [PASS]", "Password") do |p|
		options[:pass] = p
	end
	
	opts.on("-d", "--domain [DOMAIN]", "Domain") do |d|
		options[:domain] = d
	end
	
end.parse!

puts "Welcome to Jon's Opinion Lab Script."

# set domain
olab_data_realm = options[:domain]

# set dates
# - accepts different date formats
# 		"MM/DD/YYYY"
# 		"MM/DD/YYYY HH:MM"

# TODO: rescuing errors is probably not the best way to do this - would probably be better to do some regex to determine the format beforehand
begin
	start_date = DateTime.strptime(options[:start_date], "%m/%d/%Y")
rescue ArgumentError
	start_date = DateTime.strptime(options[:start_date], "%m/%d/%Y %k:%M")
end

begin
	end_date = DateTime.strptime(options[:end_date], "%m/%d/%Y")
rescue ArgumentError
	end_date = DateTime.strptime(options[:end_date], "%m/%d/%Y %k:%M")
end

# set login info
username = options[:username]
pass = options[:pass]

# OLAB CONFIGURATION OPTIONS
OLAB_DATE_FORMAT = "%Y-%m-%d %k:%M:%S"
OLAB_WEB_SERVICE_URL = "https://webservice.opinionlab.com/display/"
OLAB_DATA_TYPE = "domain"	# "domain", "group", or "card", though I couldn't get group/card working
OLAB_XML_STYLE = 0 			# "0" returns everything, "2" returns responses with comments only, "1" returns old style

# create the request object
# there was a problem when using "new" rather than "get" - not sure why
# should there be a timeout? sometimes their response seems really slow
response = Typhoeus::Request.get(OLAB_WEB_SERVICE_URL,
									:method => :get,
									#012-:timeout => 5000, # milliseconds
									:params => {
										:start_date => start_date.strftime(OLAB_DATE_FORMAT),
										:end_date => end_date.strftime(OLAB_DATE_FORMAT),
										:type => OLAB_DATA_TYPE,
										:realm => olab_data_realm,
										:xml_style => OLAB_XML_STYLE
									},
									:username => username,
									:password => pass				
						)

if response.code == 200
	puts "Received comments successfully"
else
	# if response isn't 200 OK, abort and show status
	error =  "There was a problem with the request - status code: " + response.code.to_s
	abort(error)
end

# feed the XML into nokogiri

doc = Nokogiri::XML(response.body) do |config|

	# important to use "strict" or else it adds in a bunch of newlines and junk
	config.strict

end

# display each data node with Nokogiri

puts "USER COMMENTS"

comment_nodes = doc.xpath("//data")
comment_nodes.each do |node|

	# need to handle a case when these paths do not exist for some reason
	
	puts "*" * 20
	
	# there is probably a lot better way to iterate through all this - create a mapping and then just go through it?
	# set the mapping and then only match if the tag exists, so don't have to do this "if" shit
	
	# ID - unique numeric identifier
	puts node['id']
	# URL - page where the comment was left
	puts URI.decode(node.at_xpath(".//url").content)
	# comments
	puts node.at_xpath(".//comments").content
	
	# CONTEXTUAL DATA
	# submission date (when the comment was left)
	puts node.at_xpath(".//contextual_data/submission_date").content
	# referrer
	puts URI.decode(node.at_xpath(".//contextual_data/referrer").content)
	# time on page
	puts node.at_xpath(".//contextual_data/time_on_page").content
	# browser user agent
	puts node.at_xpath(".//contextual_data/browser_user_agent").content
	# browser type
	puts node.at_xpath(".//contextual_data/browser_type").content
	# browser version
	puts node.at_xpath(".//contextual_data/browser_version").content
	# OS type
	puts node.at_xpath(".//contextual_data/os_type").content
	# OS version
	puts node.at_xpath(".//contextual_data/os_version").content
	# screen resolution
	puts node.at_xpath(".//contextual_data/screen_resolution").content
	# IP address
	puts node.at_xpath(".//contextual_data/ip_address").content
	
	# OPINION METRICS
	# Overall rating (when available on comment card)
	puts node.at_xpath(".//opinion_metrics/overall_rating").content
	# Content rating (when available and when answered by the user on comment card)
	puts node.at_xpath(".//opinion_metrics/content_rating").content
	# Design rating (when available and user entered)
	puts node.at_xpath(".//opinion_metrics/design_rating").content
	# Usability rating (when available and user entered)
	puts node.at_xpath(".//opinion_metrics/usability_rating").content
	# Email (when entered by the user)
	# note: we don't use this field so it shouldn't be available, but putting here for the sake of completeness
	puts node.at_xpath(".//email").content if node.at_xpath(".//email")
	
	# CUSTOM VARS
	# for now, just mush the xml into one field
	custom_vars = ""
	if node.at_xpath(".//custom_vars")
		custom_vars = node.at_xpath(".//custom_vars").to_xml.delete("\n")	# not sure how to get the inside tag values without these newlines - is the problem here or with olab's XML?
		# is it really bad to have newlines?  maybe thats better for DB insertion?
	else
		custom_vars = ""
	end
	puts custom_vars
	
	# QUESTIONS - figure out how to handle	
	# for now, just mush the xml into one field
	custom_questions = ""
	if node.at_xpath(".//custom_questions")
		custom_questions = node.at_xpath(".//custom_questions").to_xml.delete("\n")
	else
		custom_vars = ""
	end
	puts custom_questions
	
	puts ""
	
end

# print the custom questions
question_nodes = doc.xpath("//custom_question_def/question_text")
puts "CUSTOM QUESTIONS" if question_nodes.count > 0
question_nodes.each do |question|
	
	puts "*" * 20
	puts question['id']
	puts question.content

end
