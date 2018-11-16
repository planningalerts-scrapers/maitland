require 'scraperwiki'
require 'mechanize'

class Hash
  def has_blank?
    self.values.any?{|v| v.nil? || v.length == 0}
  end
end

base_url  = "https://myhorizon.maitland.nsw.gov.au/Horizon/logonOp.aw?e=FxkUAB1eSSgbAR0MXx0aEBcRFgEzEQE6F10WSz4UEUMAZgQSBwVHHAQdXBNFETMAQkZFBEZAXxERQgcwERAAH0YWSzgRBFwdIxUHHRleNAMcEgA%3D#/home"
thisweek  = "https://myhorizon.maitland.nsw.gov.au/Horizon/urlRequest.aw?actionType=run_query_action&query_string=FIND+Applications+WHERE+Applications.ApplicationTypeID.IsAvailableOnline%3D%27Yes%27+AND+Applications.CanDisclose%3D%27Yes%27+AND+NOT(Applications.StatusName+IN+%27Pending%27%2C+%27Cancelled%27)+AND+WEEK(Applications.Lodged)%3DCURRENT_WEEK-1+AND+YEAR(Applications.Lodged)%3DCURRENT_YEAR+AND+Application.ApplicationTypeID.Classification%3D%27Application%27+ORDER+BY+Applications.Lodged+DESC&query_name=Application_LodgedThisWeek&take=100&skip=0&start=0&pageSize=100"
thismonth = "https://myhorizon.maitland.nsw.gov.au/Horizon/urlRequest.aw?actionType=run_query_action&query_string=FIND+Applications+WHERE+Applications.ApplicationTypeID.IsAvailableOnline%3D%27Yes%27+AND+Applications.CanDisclose%3D%27Yes%27+AND+NOT(Applications.StatusName+IN+%27Pending%27%2C+%27Cancelled%27)+AND+MONTH(Applications.Lodged)%3DCURRENT_MONTH+AND+YEAR(Applications.Lodged)%3DCURRENT_YEAR+AND+Application.ApplicationTypeID.Classification%3D%27Application%27+ORDER+BY+Applications.Lodged+DESC&query_name=Application_LodgedThisMonth&take=100&skip=0&start=0&pageSize=100"
lastmonth = "https://myhorizon.maitland.nsw.gov.au/Horizon/urlRequest.aw?actionType=run_query_action&query_string=FIND+Applications+WHERE+Applications.ApplicationTypeID.IsAvailableOnline%3D%27Yes%27+AND+Applications.CanDisclose%3D%27Yes%27+AND+NOT(Applications.StatusName+IN+%27Pending%27%2C+%27Cancelled%27)+AND+MONTH(Applications.Lodged-1)%3DCURRENT_MONTH-1+AND+YEAR(Applications.Lodged)%3DCURRENT_YEAR+AND+Application.ApplicationTypeID.Classification%3D%27Application%27+ORDER+BY+Applications.Lodged+DESC&query_name=Application_LodgedLastMonth&take=100&skip=0&start=0&pageSize=100"

comment_url = "mailto:info@maitland.nsw.gov.au"

time = Time.new

case ENV['MORPH_PERIOD']
  when 'lastmonth'
    dateFrom = (Date.new(time.year, time.month, 1) << 1).strftime('%d/%m/%Y')
    dateTo   = (Date.new(time.year, time.month, 1)-1).strftime('%d/%m/%Y')
    data_url = lastmonth
  when 'thismonth'
    dateFrom = Date.new(time.year, time.month, 1).strftime('%d/%m/%Y')
    dateTo   = Date.new(time.year, time.month, -1).strftime('%d/%m/%Y')
    data_url = thismonth
  else
    dateFrom = (Date.new(time.year, time.month, time.day)-7).strftime('%d/%m/%Y')
    dateTo   = Date.new(time.year, time.month, time.day).strftime('%d/%m/%Y')
    data_url = thisweek
end

puts "Scraping from " + dateFrom + " to " + dateTo + ", changable via MORPH_PERIOD variable"

agent = Mechanize.new
page = agent.get(base_url)
page = agent.get(data_url)
records = page.search("//row")

records.each do |r|
  record = {}
  record["council_reference"] = r.at("EntryAccount")["org_value"] rescue nil
  record["address"]           = r.at("PropertyDescription")["org_value"].split(",")[0] rescue nil
  record["description"]       = r.at("Details")["org_value"] rescue nil
  record["info_url"]          = "https://myhorizon.maitland.nsw.gov.au/Horizon/embed.html"
  record["comment_url"]       = comment_url
  record["date_scraped"]      = Date.today.to_s
  record["date_received"]     = Date.strptime(r.at("Lodged")["org_value"], '%d/%m/%Y').to_s rescue nil

  unless record.has_blank?
    if (ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true)
      puts "Saving record " + record['council_reference'] + ", " + record['address']
#       puts record
      ScraperWiki.save_sqlite(['council_reference'], record)
    else
      puts "Skipping already saved record " + record['council_reference']
    end
  end
end

