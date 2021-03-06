require './spec/spec_helper'

PROJECTS_CONFIG_MYSQL = 'spec/configs/mysql/projects.yaml'
STORES_CONFIG_MYSQL = 'spec/configs/mysql/stores.yaml'


describe "Backzilla", "mysql", "backup preparation" do
  before :each do
    projects_file = File.expand_path PROJECTS_CONFIG_MYSQL
    data = YAML.load_file projects_file
    projects = data.inject([]) do |projects, project_data|
      project_name, project_entities_data = *project_data
      data[project_name].each do |entity_name, entity_data|
        $password = entity_data['password']
        $user = entity_data['user']
        @mysql = Backzilla::Entity::MySQL.new('test', entity_data)
      end
    end
    create_mysql_database
    @mysql.project = Backzilla::Project.new('test')
  end

  it "should prepare mysql database to be backed up" do
    # Before running this test you should create mysql dump manually and move resultant file "backzilla_test.sql" to
    # #{APP_ROOT}/spec/fixtures/mysql/
    path = Pathname.new(@mysql.prepare_backup)
    path.should == Pathname.new("/tmp/backzilla/test/test/backzilla_test.sql")
    flaga = false
    file1 = File.new(path, "r")
    file2 = File.new('spec/fixtures/mysql/backzilla_test.sql', "r")
    while (line1 = file1.gets)
      line2 = file2.gets
      unless line1.include? "-- Dump completed"
        unless line1.include? "-- Server version"
          line1.should == line2
        end
      end
    end
    file1.close
    file2.close
  end
end

describe "Backzilla", "mysql", "finalize restore" do
  before :each do
    projects_file = File.expand_path PROJECTS_CONFIG_MYSQL
    data = YAML.load_file projects_file
      projects = data.inject([]) do |projects, project_data|
        project_name, project_entities_data = *project_data
        data[project_name].each do |entity_name, entity_data|
          @mysql = Backzilla::Entity::MySQL.new('test', entity_data)
        end
      end
    @mysql.project = Backzilla::Project.new('test')
  end

  after(:all) do
    drop_mysql_database
  end

  it "should restore mysql database from given file" do
    modify_mysql_database
    @mysql.finalize_restore
    cmd =<<-CMD
      echo "select * from backzilla_test.users; " |\
      mysql -u #{$user} -p#{$password}
    CMD
   tmp = `#{cmd}`
   tmp.should_not include "Kacper the friendly ghost"
  end
end

