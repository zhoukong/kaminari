# frozen_string_literal: true
require 'test_helper'

if defined?(::Rails::Railtie) && defined?(::ActionView)
  class ActionViewExtensionTest < ActionView::TestCase
    setup do
      self.output_buffer = ::ActionView::OutputBuffer.new
    end
    teardown do
      User.delete_all
    end
    sub_test_case '#paginate' do
      setup do
        50.times {|i| User.create! name: "user#{i}"}
        @users = User.page(1)
      end

      test 'returns a String' do
        assert_kind_of String, view.paginate(@users, params: {controller: 'users', action: 'index'})
      end

      test 'escaping the pagination for javascript' do
        assert_nothing_raised do
          escape_javascript(view.paginate @users, params: {controller: 'users', action: 'index'})
        end
      end

      test 'accepts :theme option' do
        begin
          controller.append_view_path File.join(Gem.loaded_specs['kaminari-core'].gem_dir, 'test/fake_app/views')

          html = view.paginate @users, theme: 'bootstrap', params: {controller: 'users', action: 'index'}
          assert_match(/bootstrap-paginator/, html)
          assert_match(/bootstrap-page-link/, html)
        ensure
          controller.view_paths.pop
        end
      end

      test 'accepts :views_prefix option' do
        begin
          controller.append_view_path File.join(Gem.loaded_specs['kaminari-core'].gem_dir, 'test/fake_app/views')

          assert_equal "  <b>1</b>\n", view.paginate(@users, views_prefix: 'alternative/', params: {controller: 'users', action: 'index'})
        ensure
          controller.view_paths.pop
        end
      end

      test 'accepts :paginator_class option' do
        custom_paginator = Class.new(Kaminari::Helpers::Paginator) do
          def to_s
            "CUSTOM PAGINATION"
          end
        end

        assert_equal 'CUSTOM PAGINATION', view.paginate(@users, paginator_class: custom_paginator, params: {controller: 'users', action: 'index'})
      end

      test 'total_pages: 3' do
        assert_match(/<a href="\/users\?page=3">Last/, view.paginate(@users, total_pages: 3, params: {controller: 'users', action: 'index'}))
      end

      test "page: 20 (out of range)" do
        users = User.page(20)

        html = view.paginate users, params: {controller: 'users', action: 'index'}
        assert_not_match(/Last/, html)
        assert_not_match(/Next/, html)
      end
    end

    sub_test_case '#link_to_previous_page' do
      setup do
        60.times {|i| User.create! name: "user#{i}"}
      end

      sub_test_case 'having previous pages' do
        setup do
          @users = User.page(3)
        end

        test 'the default behaviour' do
          html = view.link_to_previous_page @users, 'Previous', params: {controller: 'users', action: 'index'}
          assert_match(/page=2/, html)
          assert_match(/rel="prev"/, html)

          html = view.link_to_previous_page @users, 'Previous', params: {controller: 'users', action: 'index'} do 'At the Beginning' end
          assert_match(/page=2/, html)
          assert_match(/rel="prev"/, html)
        end

        test 'overriding rel=' do
          assert_match(/rel="external"/, view.link_to_previous_page(@users, 'Previous', rel: 'external', params: {controller: 'users', action: 'index'}))
        end

        test 'with params' do
          params[:status] = 'active'

          assert_match(/status=active/, view.link_to_previous_page(@users, 'Previous', params: {controller: 'users', action: 'index'}))
        end
      end

      test 'the first page' do
        users = User.page(1)

        assert_nil view.link_to_previous_page(users, 'Previous', params: {controller: 'users', action: 'index'})
        assert_equal 'At the Beginning', (view.link_to_previous_page(users, 'Previous', params: {controller: 'users', action: 'index'}) do 'At the Beginning' end)
      end

      test 'out of range' do
        users = User.page(5)

        assert_nil view.link_to_previous_page(users, 'Previous', params: {controller: 'users', action: 'index'})
        assert_equal 'At the Beginning', (view.link_to_previous_page(users, 'Previous', params: {controller: 'users', action: 'index'}) do 'At the Beginning' end)
      end
    end

    sub_test_case '#link_to_next_page' do
      setup do
        50.times {|i| User.create! name: "user#{i}"}
      end

      sub_test_case 'having more page' do
        setup do
          @users = User.page(1)
        end

        test 'the default behaviour' do
          html = view.link_to_next_page @users, 'More', params: {controller: 'users', action: 'index'}
          assert_match(/page=2/, html)
          assert_match(/rel="next"/, html)
        end

        test 'overriding rel=' do
          assert_match(/rel="external"/, view.link_to_next_page(@users, 'More', rel: 'external', params: {controller: 'users', action: 'index'}))
        end

        test 'with params' do
          params[:status] = 'active'

          assert_match(/status=active/, view.link_to_next_page(@users, 'More', params: {controller: 'users', action: 'index'}))
        end
      end

      test 'the last page' do
        users = User.page(2)

        assert_nil view.link_to_next_page(users, 'More', params: {controller: 'users', action: 'index'})
      end

      test 'out of range' do
        users = User.page(5)

        assert_nil view.link_to_next_page(users, 'More', params: {controller: 'users', action: 'index'})
      end
    end

    sub_test_case '#page_entries_info' do
      sub_test_case 'on a model without namespace' do
        setup do
          @users = User.page(1).per(25)
        end

        sub_test_case 'having no entries' do
          test 'with default entry name' do
            assert_equal 'No users found', view.page_entries_info(@users)
          end

          test 'setting the entry name option to "member"' do
            assert_equal 'No members found', view.page_entries_info(@users, entry_name: 'member')
          end
        end

        sub_test_case 'having 1 entry' do
          setup do
            User.create! name: 'user1'
            @users = User.page(1).per(25)
          end

          test 'with default entry name' do
            assert_equal 'Displaying <b>1</b> user', view.page_entries_info(@users)
          end

          test 'setting the entry name option to "member"' do
            assert_equal 'Displaying <b>1</b> member', view.page_entries_info(@users, entry_name: 'member')
          end
        end

        sub_test_case 'having more than 1 but less than a page of entries' do
          setup do
            10.times {|i| User.create! name: "user#{i}"}
            @users = User.page(1).per(25)
          end

          test 'with default entry name' do
            assert_equal 'Displaying <b>all 10</b> users', view.page_entries_info(@users)
          end

          test 'setting the entry name option to "member"' do
            assert_equal 'Displaying <b>all 10</b> members', view.page_entries_info(@users, entry_name: 'member')
          end
        end

        sub_test_case 'having more than one page of entries' do
          setup do
            50.times {|i| User.create! name: "user#{i}"}
          end

          sub_test_case 'the first page' do
            setup do
              @users = User.page(1).per(25)
            end

            test 'with default entry name' do
              assert_equal 'Displaying users <b>1&nbsp;-&nbsp;25</b> of <b>50</b> in total', view.page_entries_info(@users)
            end

            test 'setting the entry name option to "member"' do
              assert_equal 'Displaying members <b>1&nbsp;-&nbsp;25</b> of <b>50</b> in total', view.page_entries_info(@users, entry_name: 'member')
            end
          end

          sub_test_case 'the next page' do
            setup do
              @users = User.page(2).per(25)
            end

            test 'with default entry name' do
              assert_equal 'Displaying users <b>26&nbsp;-&nbsp;50</b> of <b>50</b> in total', view.page_entries_info(@users)
            end

            test 'setting the entry name option to "member"' do
              assert_equal 'Displaying members <b>26&nbsp;-&nbsp;50</b> of <b>50</b> in total', view.page_entries_info(@users, entry_name: 'member')
            end
          end

          sub_test_case 'the last page' do
            setup do
              User.max_pages_per 4
              @users = User.page(4).per(10)
            end
            teardown do
              User.max_pages_per nil
            end

            test 'with default entry name' do
              assert_equal 'Displaying users <b>31&nbsp;-&nbsp;40</b> of <b>50</b> in total', view.page_entries_info(@users)
            end
          end
        end
      end

      sub_test_case 'I18n' do
        setup do
          50.times {|i| User.create! name: "user#{i}"}
          @users = User.page(1).per(25)
          I18n.backend.store_translations(:en, User.i18n_scope => { models: { user: { one: "person", other: "people" } } })
        end
        teardown do
          I18n.backend.reload!
        end

        test 'page_entries_info translates entry' do
          assert_equal 'Displaying people <b>1&nbsp;-&nbsp;25</b> of <b>50</b> in total', view.page_entries_info(@users)
        end
      end

      sub_test_case 'on a model with namespace' do
        setup do
          @addresses = User::Address.page(1).per(25)
        end

        test 'having no entries' do
          assert_equal 'No addresses found', view.page_entries_info(@addresses)
        end

        sub_test_case 'having 1 entry' do
          setup do
            User::Address.create!
            @addresses = User::Address.page(1).per(25)
          end

          test 'with default entry name' do
            assert_equal 'Displaying <b>1</b> address', view.page_entries_info(@addresses)
          end

          test 'setting the entry name option to "place"' do
            assert_equal 'Displaying <b>1</b> place', view.page_entries_info(@addresses, entry_name: 'place')
          end
        end

        sub_test_case 'having more than 1 but less than a page of entries' do
          setup do
            10.times { User::Address.create! }
            @addresses = User::Address.page(1).per(25)
          end

          test 'with default entry name' do
            assert_equal 'Displaying <b>all 10</b> addresses', view.page_entries_info(@addresses)
          end

          test 'setting the entry name option to "place"' do
            assert_equal 'Displaying <b>all 10</b> places', view.page_entries_info(@addresses, entry_name: 'place')
          end
        end

        sub_test_case 'having more than one page of entries' do
          setup do
            50.times { User::Address.create! }
          end

          sub_test_case 'the first page' do
            setup do
              @addresses = User::Address.page(1).per(25)
            end

            test 'with default entry name' do
              assert_equal 'Displaying addresses <b>1&nbsp;-&nbsp;25</b> of <b>50</b> in total', view.page_entries_info(@addresses)
            end

            test 'setting the entry name option to "place"' do
              assert_equal 'Displaying places <b>1&nbsp;-&nbsp;25</b> of <b>50</b> in total', view.page_entries_info(@addresses, entry_name: 'place')
            end
          end

          sub_test_case 'the next page' do
            setup do
              @addresses = User::Address.page(2).per(25)
            end

            test 'with default entry name' do
              assert_equal 'Displaying addresses <b>26&nbsp;-&nbsp;50</b> of <b>50</b> in total', view.page_entries_info(@addresses)
            end

            test 'setting the entry name option to "place"' do
              assert_equal 'Displaying places <b>26&nbsp;-&nbsp;50</b> of <b>50</b> in total', view.page_entries_info(@addresses, entry_name: 'place')
            end
          end
        end
      end

      test 'on a PaginatableArray' do
        numbers = Kaminari.paginate_array(%w{one two three}).page(1)

        assert_equal 'Displaying <b>all 3</b> entries', view.page_entries_info(numbers)
      end
    end

    sub_test_case '#rel_next_prev_link_tags' do
      setup do
        31.times {|i| User.create! name: "user#{i}"}
      end


      test 'the first page' do
        users = User.page(1).per(10)
        html = view.rel_next_prev_link_tags users, params: {controller: 'users', action: 'index'}

        assert_not_match(/rel="prev"/, html)
        assert_match(/rel="next"/, html)
        assert_match(/\?page=2/, html)
      end

      test 'the second page' do
        users = User.page(2).per(10)
        html = view.rel_next_prev_link_tags users, params: {controller: 'users', action: 'index'}

        assert_match(/rel="prev"/, html)
        assert_not_match(/\?page=1/, html)
        assert_match(/rel="next"/, html)
        assert_match(/\?page=3/, html)
      end

      test 'the last page' do
        users = User.page(4).per(10)
        html = view.rel_next_prev_link_tags users, params: {controller: 'users', action: 'index'}

        assert_match(/rel="prev"/, html)
        assert_match(/\?page=3"/, html)
        assert_not_match(/rel="next"/, html)
      end
    end

    sub_test_case '#path_to_next_page' do
      setup do
        2.times {|i| User.create! name: "user#{i}"}
      end

      test 'the first page' do
        users = User.page(1).per(1)
        assert_equal '/users?page=2', view.path_to_next_page(users, params: {controller: 'users', action: 'index'})
      end

      test 'the last page' do
        users = User.page(2).per(1)
        assert_nil view.path_to_next_page(users, params: {controller: 'users', action: 'index'})
      end
    end

    sub_test_case '#path_to_prev_page' do
      setup do
        3.times {|i| User.create! name: "user#{i}"}
      end

      test 'the first page' do
        users = User.page(1).per(1)
        assert_nil view.path_to_prev_page(users, params: {controller: 'users', action: 'index'})
      end

      test 'the second page' do
        users = User.page(2).per(1)
        assert_equal '/users', view.path_to_prev_page(users, params: {controller: 'users', action: 'index'})
      end

      test 'the last page' do
        users = User.page(3).per(1)
        assert_equal'/users?page=2', view.path_to_prev_page(users, params: {controller: 'users', action: 'index'})
      end
    end
  end
end
