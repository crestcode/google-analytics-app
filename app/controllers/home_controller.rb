class HomeController < ApplicationController
   def index
     @reporting_start_date = params[:reporting_start_date]
     @reporting_end_date = params[:reporting_end_date]

     google_data = GoogleAnalytics::get_google_data(@reporting_start_date, @reporting_end_date)
     @visitors = google_data[:visitors]
     @top_viewed_products = google_data[:top_products]
   end
end