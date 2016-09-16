require 'scraperwiki'
require 'mechanize'

class Hash
  def has_blank?
    self.values.any?{|v| v.nil? || v.length == 0}
  end
end

base_url  = "https://myhorizon.maitland.nsw.gov.au/Horizon/logonGuest.aw?domain=horizondap#/home"
thisweek  = "https://myhorizon.maitland.nsw.gov.au/Horizon/urlRequest.aw?actionType=run_query_action&query_string=FIND+Applications+WHERE+WEEK(Applications.Lodged)%3DCURRENT_WEEK-1+AND+YEAR(Applications.Lodged)%3DCURRENT_YEAR+AND+Applications.CanDisclose%3D%27Yes%27+ORDER+BY+Applications.AppYear+DESC%2CApplications.AppNumber+DESC&query_name=SubmittedThisWeek&take=500&skip=0&start=0&pageSize=500"
thismonth = "https://myhorizon.maitland.nsw.gov.au/Horizon/urlRequest.aw?actionType=run_query_action&query_string=FIND+Applications+WHERE+MONTH(Applications.Lodged)%3DCURRENT_MONTH+AND+YEAR(Applications.Lodged)%3DCURRENT_YEAR+ORDER+BY+Applications.AppYear+DESC%2CApplications.AppNumber+DESC&query_name=SubmittedThisMonth&take=500&skip=0&start=0&pageSize=500"
lastmonth = "https://myhorizon.maitland.nsw.gov.au/Horizon/urlRequest.aw?actionType=run_query_action&query_string=FIND+Applications+WHERE+MONTH(Applications.Lodged-1)%3DSystemSettings.SearchMonthPrevious+AND+YEAR(Applications.Lodged)%3DSystemSettings.SearchYear+AND+Applications.CanDisclose%3D%27Yes%27+ORDER+BY+Applications.AppYear+DESC%2CApplications.AppNumber+DESC&query_name=SubmittedLastMonth&take=500&skip=0&start=0&pageSize=500"

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
  record["council_reference"] = r.at("AccountNumber")["org_value"]
  record["address"]           = r.at("Property")["org_value"]
  record["description"]       = r.at("Description")["org_value"]
  record["info_url"]          = base_url
  record["comment_url"]       = comment_url
  record["date_scraped"]      = Date.today.to_s
  record["date_received"]     = Date.strptime(r.at("Lodged")["org_value"], '%d/%m/%Y').to_s

  if ( !record.has_blank? )
    if (ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true)
      puts "Saving record " + record['council_reference'] + ", " + record['address']
      # puts record
      ScraperWiki.save_sqlite(['council_reference'], record)
    else
      puts "Skipping already saved record " + record['council_reference']
    end
  end
end

