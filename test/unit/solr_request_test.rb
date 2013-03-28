require "test_helper"

class SolrRequestTest < ActiveSupport::TestCase
  
  def build_query_test_once(params, expected)
    req = SolrRequest.new(params)
    assert_equal(expected, req.build_query)
  end
  
  test "build_query_test" do
    build_query_test_once({:everything => "everyFoo"}, "q=everything:everyFoo")
    build_query_test_once({:everything => "foo bar blaz"}, 'q=everything:"foo bar blaz"')
    build_query_test_once({:everything => "everyTitle", :title => "titleFoo"},
        "q=everything:everyTitle AND title:titleFoo")
    build_query_test_once({:author => "Joe Bob", :subject => "Virology"},
        'q=author:"Joe Bob" AND subject:Virology')
        
    # Empty fields should not be added.
    build_query_test_once({:everything => "ignoreRest", :author => "", :subject => "  "},
        "q=everything:ignoreRest")
        
    # Hack where the "pseudo-fields" author_country and institution both map to the actual
    # solr field affiliate.
    build_query_test_once({:author_country => "authorCountry"}, "q=affiliate:authorCountry")
    build_query_test_once({:everything => "everythingInst", :institution => "foo institution"},
        'q=affiliate:"foo institution" AND everything:everythingInst')
    build_query_test_once({:author_country => "france", :institution => "university of lyon"},
        'q=affiliate:(france AND "university of lyon")')
    build_query_test_once({:everything => "some keywords", :author_country => "USA",
        :institution => "stanford u", :subject => "ebola virus"},
        'q=affiliate:(USA AND "stanford u") AND everything:"some keywords" AND subject:"ebola virus"')
        
    # cross_published_journal_name should be ignored iff it equals "All Journals".
    build_query_test_once({:everything => "fooCross", :cross_published_journal_name => "PLOS ONE"},
        'q=cross_published_journal_name:"PLOS ONE" AND everything:fooCross')
    build_query_test_once(
        {:everything => "fooNoJournal", :cross_published_journal_name => "All Journals"},
        "q=everything:fooNoJournal")
  end

end
