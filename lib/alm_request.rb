require "net/http"
require "open-uri"
require "json"

# Interface to the PLOS ALM API.
module AlmRequest
  
  # TODO add this to the config file, not hardcoded
  @@URL = "http://alm.plos.org/api/v3/articles"
  
  
  # Processes the "Counter" data source and returns a tuple of (HTML views, PDF views, XML views)
  # for a given article.
  def self.aggregate_plos_views(events_data)
    views = 0
    pdfs = 0
    xmls = 0
    events_data.each do |event|
      views += event["html_views"].to_i
      pdfs += event["pdf_views"].to_i
      xmls += event["xml_views"].to_i
    end
    return {:html => views, :pdf => pdfs, :xml => xmls}
  end
  
  
  # Processes the "PubMed Central Usage Stats" data source and returns a tuple of
  # (HTML views, PDF views) for a given article.
  def self.aggregate_pmc_views(pmc_source)
    views = 0
    pdf = 0
    if pmc_source["events"]
      pmc_source["events"].each do |event|
        views += event["full-text"].to_i
        pdf += event["pdf"].to_i
      end
    end
    return views, pdf
  end

  # Returns a dict containing ALM usage data for a given list of articles.
  def self.get_data_for_articles(report_dois)

    all_results = {}

    dois = report_dois.map { |report_doi| report_doi.doi }

    # get alm data from cache
    dois.delete_if  do | doi |
      results = Rails.cache.read("#{doi}.alm")
      if !results.nil?
        all_results[doi] = results
        true
      end
    end

    # https://github.com/articlemetrics/alm/wiki/API
    # Queries for up to 50 articles at a time are supported.
    # TODO configure
    num_articles = 50

    start_index = 0
    end_index = start_index + num_articles
    subset_dois = dois[start_index, end_index]

    while (!subset_dois.nil? && !subset_dois.empty?)
      params = {}
      params[:ids] = subset_dois.join(",")
      params[:info] = 'event'

      url = "#{@@URL}/?#{params.to_param}"

      Rails.logger.debug("ALM DATA REQUEST: #{url}")

      resp = Net::HTTP.get_response(URI.parse(url))

      if !resp.kind_of?(Net::HTTPSuccess)
        raise "Server returned #{resp.code}: " + resp.body
      end

      json = JSON.parse(resp.body)

      json.each do | article |
        sources = article["sources"].map { | source | (source["name"].casecmp("counter") != 0) ? [source["name"], source["metrics"]] : [source["name"], source["events"]] }
        sources_dict = Hash[*sources.flatten(1)]

        results = {}

        views = aggregate_plos_views(sources_dict["counter"])
        results[:plos_html] = views[:html]
        results[:plos_pdf] = views[:pdf]
        results[:plos_xml] = views[:xml]

        results[:pmc_views] = sources_dict["pmc"]["html"].to_i
        results[:pmc_pdf] = sources_dict["pmc"]["pdf"].to_i

        results[:total_usage] = results[:plos_html] + results[:plos_pdf] + results[:plos_xml] + results[:pmc_views] + results[:pmc_pdf]
        results[:usage_data_present] = (results[:total_usage] > 0)

        results[:pmc_citations] = sources_dict["pubmed"]["total"].to_i
        results[:crossref_citations] = sources_dict["crossref"]["total"].to_i
        results[:scopus_citations] = sources_dict["scopus"]["total"].to_i
        results[:citation_data_present] = (results[:pmc_citations] + results[:crossref_citations] + results[:scopus_citations]) > 0

        results[:citeulike] = sources_dict["citeulike"]["total"].to_i
        results[:connotea] = sources_dict["connotea"]["total"].to_i
        results[:mendeley] = sources_dict["mendeley"]["total"].to_i
        results[:twitter] = sources_dict["twitter"]["total"].to_i
        results[:facebook] = sources_dict["facebook"]["total"].to_i
        results[:social_network_data_present] = (results[:citeulike] + results[:connotea] + results[:mendeley] + results[:twitter] + results[:facebook]) > 0

        results[:nature] = sources_dict["nature"]["total"].to_i
        results[:research_blogging] = sources_dict["researchblogging"]["total"].to_i
        results[:wikipedia] = sources_dict["wikipedia"]["total"].to_i
        results[:blogs_data_present] = (results[:nature] + results[:research_blogging] + results[:wikipedia]) > 0

        all_results[article["doi"]] = results

        # store alm data in cache
        Rails.cache.write("#{article["doi"]}.alm", results, :expires_in => 1.day)
      end

      start_index = end_index
      end_index = start_index + num_articles
      subset_dois = dois[start_index, end_index]
    end

    return all_results
  end
  
end
