#!/usr/bin/env ruby
Bundler.require

url = "https://myhorizon.maitland.nsw.gov.au/Horizon/@@horizondap@@/atdis/1.0/"

ATDISPlanningAlertsFeed.save(url)