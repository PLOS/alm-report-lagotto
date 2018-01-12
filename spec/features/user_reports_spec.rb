require 'rails_helper'

#TODO:FIX
describe 'generate report', skip: true, type: :feature, vcr: true do
  if Search.plos?
    it 'loads the visualization for multiple articles', js: true do
      visit '/'
      sign_in

      fill_in 'everything', with: 'cancer'
      click_button 'Search'
      expect(page).to have_content 'Cancer-Drug Associations: A Complex System'
      expect(page).to have_button('Preview List (0)', disabled: true)

      first('.article-info').find('input.check-save-article').click
      expect(page).to have_button('Preview List (1)')
      all('.article-info')[5].find('input.check-save-article').click
      expect(page).to have_button('Preview List (2)')
      find_button('Preview List (2)').click
      expect(page).to have_content 'Cancer-Drug Associations: A Complex System'
      click_button 'Create Report'

      expect(page).to have_content('Metrics Data')

      visit '/'
      expect(page).to have_content('Your previous reports')
      expect(page).to have_css('a .number')
    end
  elsif Search.crossref?
    it "loads the visualization for a multiple articles", js: true do
      visit "/"
      sign_in

      fill_in "everything",
        with: "A Future Vision for PLOS Computational Biology"

      click_button "Search"

      first(".article-info").find("input.check-save-article").click
      expect(page).to have_button("Preview List (1)")
      click_link("3")

      all(".article-info")[2].find("input.check-save-article").click

      expect(page).to have_button("Preview List (2)")
      find_button("Preview List (2)").click
      expect(page).to have_content "A Future Vision for PLOS Computational Biology"
      click_button "Create Report"

      expect(page).to have_content("Metrics Data")

      visit '/'
      expect(page).to have_content('Your previous reports')
      expect(page).to have_css('a .number')
    end
  end
end

