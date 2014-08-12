require 'google/api_client'

module GoogleAnalytics

  def self.get_google_data(selected_start_date = nil, selected_end_date = nil)
    # connect to GA
    client = self.connect_to_google
    analytics = client.discovered_api('analytics', 'v3')
    profile_id = ENV['ga_profile_id']

    # if no specified start date, set to earliest start date possible for Google API (Jan 1, 2005)
    start_date = selected_start_date.blank? ? '2005-01-01' : DateTime.parse(Time.parse(selected_start_date).to_s).strftime("%Y-%m-%d")
    end_date = selected_end_date.blank? ? DateTime.now.strftime("%Y-%m-%d") : DateTime.parse(Time.parse(selected_end_date).to_s).strftime("%Y-%m-%d")

    visitors = get_visitor_data(client, analytics, profile_id, start_date, end_date)
    top_products = get_top_products_data(client, analytics, profile_id, start_date, end_date)

    return {:visitors => visitors, :top_products => Hash[top_products.sort_by { |id1| -id1[1][:unique_pageviews] }]}
  end

  def self.connect_to_google
    client = Google::APIClient.new
    key_file = Dir.glob(Rails.root.join('lib', 'google_analytics', '*.p12')).first
    key = Google::APIClient::KeyUtils.load_from_pkcs12(key_file, 'notasecret')
    service_account = Google::APIClient::JWTAsserter.new(ENV['ga_issuer'], 'https://www.googleapis.com/auth/analytics.readonly', key)
    client.authorization = service_account.authorize
    return client
  end

  def self.get_visitor_data(client, analytics, profile_id, start_date, end_date)
    visit_count = client.execute(:api_method => analytics.data.ga.get, :parameters => {'ids' => "ga:" + profile_id, 'start-date' => start_date, 'end-date' => end_date, 'metrics' => "ga:sessions,ga:newUsers,ga:percentNewSessions"})
    visitors = {}
    visitors[:all_visits] = visit_count.data.rows[0][0]
    visitors[:number_of_new_visitors] = visit_count.data.rows[0][1]
    visitors[:percent_new_visitors] = visit_count.data.rows[0][2].to_f.round(1).to_s
    visitors[:number_of_returning_visitors] = (visitors[:all_visits].to_i - visitors[:number_of_new_visitors].to_i).to_s
    visitors[:percent_returning_visitors] = (100-visitors[:percent_new_visitors].to_f).round(1).to_s
    return visitors
  end

  def self.get_top_products_data(client, analytics, profile_id, start_date, end_date)
    product_page_count = client.execute(:api_method => analytics.data.ga.get, :parameters => {'ids' => "ga:" + profile_id, 'start-date' => start_date, 'end-date' => end_date, 'dimensions' => "ga:pagePath", 'metrics' => "ga:pageviews,ga:uniquePageviews,ga:timeOnPage", 'sort' => "-ga:pageviews", 'filters' => "ga:pagePath=~^/product/details/,ga:pagePath=~/dp/"})

    top_products = {}
    product_page_count.data.rows.each do |product_page|
      # sum pageview data across all urls with matching product ids
      if product_id = product_page[0].match(/(?:dp|details)\/(\d+)/)
        product_id = product_id.captures[0].to_s
        pageviews = product_page[1].to_i
        unique_pageviews = product_page[2].to_i

        if top_products[product_id]
          top_products[product_id][:pageviews] += pageviews
          top_products[product_id][:unique_pageviews] += unique_pageviews
        else
          top_products[product_id] = {:pageviews => pageviews, :unique_pageviews => unique_pageviews}
        end
      end
    end
    return top_products
  end
end