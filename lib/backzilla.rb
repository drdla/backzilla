require 'yaml'
require 'pp'
require 'ostruct'
require 'logger'
require 'fileutils'
require 'pathname'

require 'rubygems'
require 'open4'

class Object
  def blank?
    respond_to?(:empty?) ? empty? : !self
  end
end

module Backzilla
  autoload :LoggerHelper, 'backzilla/logger_helper'
  autoload :Project, 'backzilla/project'
  autoload :Entity, 'backzilla/entity'
  autoload :Store, 'backzilla/store'
  autoload :Executor, 'backzilla/executor'
  autoload :Version, 'backzilla/version'
  autoload :Configuration, 'backzilla/configuration'

  include Backzilla::Version
  include Backzilla::Executor
  extend Backzilla::LoggerHelper

  STORES_CONFIG = ENV["BACKZILLA_STORES_CONFIG"] || "~/.backzilla/stores.yaml"
  PROJECTS_CONFIG = ENV["BACKZILLA_PROJECTS_CONFIG"] || "~/.backzilla/projects.yaml"

  def self.store(path, project_name, entity_name)
    info "Storing #{path}..."

    stores_file = File.expand_path STORES_CONFIG
    data = YAML.load_file stores_file
    Store.gnugpg_passphrase = data['gnupg_passphrase']
    stores = data['stores'].map do |store_name, store_options|
      klass = Backzilla::Store.const_get(store_options['type'])
      klass.new(store_name, store_options)
    end

    stores.each { |s| s.put path, project_name, entity_name }
  end

  def self.restore(path, project_name, entity_name)
    info "Restoring #{path}..."

    restores_file = File.expand_path STORES_CONFIG
    data = YAML.load_file restores_file
    Store.gnugpg_passphrase = data['gnupg_passphrase']
    stores = data['stores'].map do |store_name, store_options|
      klass = Backzilla::Store.const_get(store_options['type'])
      klass.new(store_name, store_options)
    end

    stores.each { |s| s.get path, project_name, entity_name }
  end

  def self.logger
    return @logger if @logger
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::DEBUG
    @logger.progname = 'Backzilla'
    @logger
  end

  def self.options
    Backzilla::Configuration.instance
  end

  def self.run(options)
    config = Backzilla::Configuration.instance
    options.each do |key, value|
      config.send "#{key}=", value
    end

    if config.backup && config.restore
      fatal "Use -r or -b separately"
      exit -1
    elsif !config.backup && !config.restore
      fatal "-r or -b required"
      exit -1
    end

    projects_file = File.expand_path PROJECTS_CONFIG
    data = YAML.load_file projects_file
    if config.spec == 'all'
      projects = data.inject([]) do |projects, project_data|
        project_name, project_entities_data = *project_data
        project = Project.new(project_name)
        project.setup_entities data[project_name]
        projects << project
      end
      projects.each { |p| config.restore ? p.restore : p.backup }
    else
      spec_parts = config.spec.split(':')
      project_name = spec_parts.shift
      unless data[project_name]
        fatal "No such project '#{project_name}'"
        exit -1
      end

      project = Project.new(project_name)
      project.setup_entities data[project_name]

      if config.backup
        project.backup spec_parts
      elsif config.restore
        project.restore spec_parts
      end
    end
  end
end

