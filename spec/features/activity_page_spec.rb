# frozen_string_literal: true

require 'rails_helper'
require "#{Rails.root}/lib/revision_analytics_service"

describe 'activity page', type: :feature, js: true do
  before do
    login_as(user, scope: :user)
    visit '/'
  end

  describe 'non-admins' do
    let(:user) { create(:user) }

    it 'is not linked for non-admins' do
      within '.top-nav' do
        expect(page).not_to have_content 'Admin'
      end
    end
  end

  describe 'admins' do
    let(:article)  { create(:article, namespace: 118) }
    let(:article2) { create(:article, namespace: 118, title: 'pandas') }
    let!(:admin)   { create(:admin) }
    let!(:user)    { create(:user) }
    let!(:user2)   { create(:user, username: 'User2') }
    let(:course)   { create(:course, end: 1.year.from_now) }
    let(:course2)  { create(:course, end: 1.year.from_now, slug: 'foo/2') }
    let!(:cu1)     { create(:courses_user, user_id: user.id, course_id: course.id) }
    let!(:cu2)     { create(:courses_user, user_id: user2.id, course_id: course2.id) }
    let!(:cu3)     { create(:courses_user, user_id: admin.id, course_id: course.id) }
    let!(:revision) do
      create(:revision,
             article_id: article.id,
             wp10: RevisionAnalyticsService::DEFAULT_DYK_WP10_LIMIT,
             user_id: user.id,
             date: 2.days.ago)
    end
    let!(:revision2) do
      create(:revision,
             article_id: article2.id,
             wp10: RevisionAnalyticsService::DEFAULT_DYK_WP10_LIMIT,
             user_id: user2.id,
             date: 3.days.ago)
    end

    before do
      login_as(admin, scope: :user)
      visit '/'
    end

    it 'is viewable by admins' do
      within '.top-nav' do
        click_link 'Admin'
      end
      click_link 'Recent Activity'
    end

    context 'dyk eligible' do
      it 'displays a list of DYK-eligible articles' do
        visit '/recent-activity'
        sleep 1
        expect(page).to have_content article.title.tr('_', ' ')
      end

      it 'filters the courses to my courses' do
        # Admin is admin of course 1, should only see user1's revision
        # when checked
        visit '/recent-activity'
        sleep 1
        within '.activity-table' do
          expect(page).to have_content article.title.tr('_', ' ')
          expect(page).to have_content article2.title.tr('_', ' ')
          expect(page).to have_content format_local_datetime revision.date
          expect(page).to have_content format_local_datetime revision2.date
        end
        check 'Show My Courses Only'
        within '.activity-table' do
          expect(page).to have_content article.title.tr('_', ' ')
          expect(page).not_to have_content article2.title.tr('_', ' ')
          expect(page).to have_content format_local_datetime revision.date
          expect(page).not_to have_content format_local_datetime revision2.date
        end
        # sleep 10
      end
    end

    context 'recent edits' do
      before do
        allow(RevisionAnalyticsService).to receive(:recent_edits)
          .and_return([revision])
      end

      it 'displays a list of recent revisions' do
        visit '/recent-activity/recent-edits'
        assert_page_content article.title.tr('_', ' ')
      end
    end

    context 'recent uploads' do
      let!(:upload) do
        create(:commons_upload,
               file_name: 'File:Blowing a raspberry.ogv',
               user_id: user.id,
               uploaded_at: 2.days.ago)
      end

      it 'displays a list of recent uploads' do
        visit '/recent-activity/recent-uploads'
        expect(page).to have_selector('div.upload')
        Capybara.ignore_hidden_elements = false
        expect(page).to have_content 'Blowing a raspberry.ogv'
        Capybara.ignore_hidden_elements = true
      end
    end
  end

  def assert_page_content(content)
    expect(page).to have_content content
  end
end
