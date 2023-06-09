require 'test_helper'

class SettingsTest < Test::Unit::TestCase
  setup_db
  
  def setup
    Settings.create!(:var => 'test',  :value => 'foo')
    Settings.create!(:var => 'test2', :value => 'bar')
    
    # Reset defaults
    Settings.defaults = {}.with_indifferent_access
  end

  def teardown
    User.delete_all
    Settings.delete_all
  end
  
  def test_defaults
    Settings.defaults[:foo] = 'default foo'
    
    assert_nil Settings.target(:foo)
    assert_equal 'default foo', Settings.foo
    
    Settings.foo = 'bar'
    assert_equal 'bar', Settings.foo
    assert_not_nil Settings.target(:foo)
  end
  
  def tests_defaults_true
    Settings.defaults[:foo] = true
    assert_equal true, Settings.foo
  end

  def tests_defaults_false
    Settings.defaults[:foo] = false
    assert_equal false, Settings.foo
  end
  
  def test_get
    assert_setting 'foo', :test
    assert_setting 'bar', :test2
  end

  def test_update
    assert_assign_setting '321', :test
  end
  
  def test_create
    assert_assign_setting '123', :onetwothree
  end
  
  def test_complex_serialization
    complex = [1, '2', {:three => true}]
    Settings.complex = complex
    assert_equal complex, Settings.complex
  end
  
  def test_serialization_of_float
    Settings.float = 0.01
    Settings.reload
    assert_equal 0.01, Settings.float
    assert_equal 0.02, Settings.float * 2
  end
  
  def test_target_scope
    user1 = User.create! :name => 'First user'
    user2 = User.create! :name => 'Second user'
    
    assert_assign_setting 1, :one, user1
    assert_assign_setting 2, :two, user2
    
    assert_setting 1, :one, user1
    assert_setting 2, :two, user2
    
    assert_setting nil, :one
    assert_setting nil, :two
    
    assert_setting nil, :two, user1
    assert_setting nil, :one, user2

    assert_equal({ "one" => 1}, user1.settings.all('one'))
    assert_equal({ "two" => 2}, user2.settings.all('two'))
    assert_equal({ "one" => 1}, user1.settings.all('o'))
    assert_equal({}, user1.settings.all('non_existing_var'))
  end

  def test_target_scope_is_instance_safe
    user1 = User.create! :name => 'First user'
    user2 = User.create! :name => 'Second user'

    assert_assign_setting 'Foo one', :foo, user1
    assert_assign_setting 'Foo two', :foo, user2

    settings_1 = user1.settings
    settings_2 = user2.settings
    assert_equal 'Foo one', settings_1.foo
  end

  def test_named_scope
    user_without_settings = User.create! :name => 'User without settings'
    user_with_settings = User.create! :name => 'User with settings'
    user_with_settings.settings.one = '1'
    user_with_settings.settings.two = '2'
    
    assert_equal [user_with_settings], User.with_settings
    assert_equal [user_with_settings], User.with_settings_for('one')
    assert_equal [user_with_settings], User.with_settings_for('two')
    assert_equal [], User.with_settings_for('foo')
    
    assert_equal [user_without_settings], User.without_settings
    assert_equal [user_without_settings], User.without_settings_for('one')
    assert_equal [user_without_settings], User.without_settings_for('two')
    assert_equal [user_without_settings, user_with_settings], User.without_settings_for('foo')
  end
  
  def test_delete_settings_after_destroying_target
    user1 = User.create! :name => 'Mr. Foo'
    user2 = User.create! :name => 'Mr. Bar'
    user1.settings.example = 42
    user2.settings.example = 43
    
    before_count = Settings.count
    user1.destroy
    assert_equal before_count - 1, Settings.count
    
    before_count = Settings.count
    user2.destroy
    assert_equal before_count - 1, Settings.count
  end
  
  def test_all
    assert_equal({ "test2" => "bar", "test" => "foo" }, Settings.all)
    assert_equal({ "test2" => "bar" }, Settings.all('test2'))
    assert_equal({ "test2" => "bar", "test" => "foo" }, Settings.all('test'))
    assert_equal({}, Settings.all('non_existing_var'))
  end
  
  def test_merge
    assert_raise(TypeError) do
      Settings.merge! :test, { :a => 1 }
    end

    Settings[:hash] = { :one => 1 }
    Settings.merge! :hash, { :two => 2 }
    assert_equal({ :one => 1, :two => 2 }, Settings[:hash])
    
    assert_raise(ArgumentError) do
      Settings.merge! :hash, 123
    end
    
    Settings.merge! :empty_hash, { :two => 2 }
    assert_equal({ :two => 2 }, Settings[:empty_hash])
  end
  
  def test_association_merge
    user = User.create! :name => 'Mr. Foo'
    user.settings.merge! :foo, { :one => 1, :two => 2}

    assert_equal({:one => 1, :two => 2}, user.settings.foo)
  end
  
  def test_destroy
    Settings.destroy :test
    assert_equal nil, Settings.test
    
    assert_raise(Settings::SettingNotFound) do
      Settings.destroy :unknown
    end
  end
  
  def test_false
    Settings.test3 = false
    assert_setting(false, 'test3')
    
    Settings.destroy :test3
    assert_setting(nil, 'test3')
  end
  
  def test_class_level_settings
    assert_equal User.settings.name, "ScopedSettings"
  end

  def test_object_inherits_class_settings_before_default
    Settings.defaults[:foo] = 'global default'
    User.settings.foo = 'model default'
    
    user = User.create! :name => 'Dwight'
    
    assert_equal user.settings.foo, 'model default'
    assert_equal 'global default', Settings.foo
  end

  def test_class_inherits_default_settings
    Settings.defaults[:foo] = 'bar'
    assert_equal User.settings.foo, 'bar'
  end

  def test_sets_settings_with_hash
    user = User.create! :name => 'Mr. Foo'
    user.settings[:one] = '1'
    user.settings[:two] = '2'
    user.settings = { :two => '2a', :three => '3' }
    
    assert_equal '1',  user.settings[:one]   # ensure existing settings remain intact
    assert_equal '2a', user.settings[:two]   # ensure settings are properly overwritten
    assert_equal '3',  user.settings[:three] # ensure new setting are created
  end

  def test_all_includes_defaults
    Settings.defaults[:foo] = 'bar'
    user = User.create! :name => 'Mr. Foo'
    assert_equal({ 'foo' => 'bar' }, user.settings.all)
  end
  
  def test_issue_18
    Settings.one = 'value1'
    User.settings.two = 'value2'
    
    assert_equal({'two' => 'value2'}, User.settings.all)
  end
  

  private
    def assert_setting(value, key, scope_target=nil)
      key = key.to_sym
      
      if scope_target
        assert_equal value, scope_target.instance_eval("settings.#{key}")
        assert_equal value, scope_target.settings[key.to_sym]
        assert_equal value, scope_target.settings[key.to_s]
      else
        assert_equal value, eval("Settings.#{key}")
        assert_equal value, Settings[key.to_sym]
        assert_equal value, Settings[key.to_s]
      end
    end
    
    def assert_assign_setting(value, key, scope_target=nil)
      key = key.to_sym
      
      if scope_target
        assert_equal value, (scope_target.settings[key] = value)
        assert_setting value, key, scope_target
        scope_target.settings[key] = nil
      
        assert_equal value, (scope_target.settings[key.to_s] = value)
        assert_setting value, key, scope_target
      else
        assert_equal value, (Settings[key] = value)
        assert_setting value, key
        Settings[key] = nil
      
        assert_equal value, (Settings[key.to_s] = value)
        assert_setting value, key
      end
    end
end