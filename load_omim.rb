#!/usr/bin/env/ruby

require 'sinatra'
require 'neography'
require 'net/http'
require 'uri'
require 'json'
require 'constructor'
require 'colorize'
require 'pry'
require 'pry_debug'

set :bind, '0.0.0.0'
neo4j_uri = URI(ENV['NEO4J_URL'] || "http://localhost:7474")
neo = Neography::Rest.new(neo4j_uri.to_s)

def check_for_neo4j(neo4j_uri)
	begin
		http			= Net::HTTP.new(neo4j_uri.host, neo4j_uri.port)
		request		= Net::HTTP::Get.new(neo4j_uri.request_uri)
		request.basic_auth(neo4j_uri.user, neo4j_uri.password) if (neo4j_uri.user)
		response	= http.request(request)

		if (response.code != "200")
			abort "Sad face. Neo4j not running. #{neo4j_uri} responded with code: #{response.code}"
		end
	rescue
		abort "Sad face. Neo4j does not appear to be running at #{neo4j_uri} ("+ $!.to_s + ")"
	end
	puts "Awesome! Neo4j is available at #{neo4j_uri}"
end

class Disorder
	constructor :name, :name_full, :type, accessors: true
	def instantiate_on_graph(neo)
		neo.create_node(
			"name" => name[0..25],
			"name_full" => name,
			"type" => type
		)
	end
end

class Locus
	constructor :name, :type, accessors: true
	def instantiate_on_graph(neo)
		neo.create_node(
			"name" => name,
			"type" => type
		)
	end
end

define_method :create_graph do
	check_for_neo4j(neo4j_uri)
	neo.create_node_auto_index
	neo.add_node_auto_index_property('name')
	File.open('morbimap.txt').each.with_index do |line, i|
		array = line.split("|").map(&:strip)
		name_cleaned = array[0].gsub(/[{?}]/, "")
		puts "-".blue * 40
		puts "[#{i}]".red + " Creating\t" + "Disorder:".green + " #{name_cleaned}"
		this_disorder = Disorder.new(name_full: name_cleaned, name: name_cleaned, type: 'Disorder').instantiate_on_graph(neo)
		array[1].split(',').map(&:strip).each do |locus_name|
			locus = Neography::Node.find("node_auto_index", "name: #{locus_name}")
			string = "Locus:".blue + "\t  #{locus_name}" 
			if !locus.nil?
				puts "[#{i}]".yellow + " Found\t" + string 
				neo.create_relationship("caused_by", this_disorder, locus)
			else
				puts "[#{i}]".yellow + " Creating\t" + string 
				this_locus = Locus.new(name: locus_name, type: "Locus").instantiate_on_graph(neo)
				neo.create_relationship("caused_by", this_disorder, this_locus)
			end
		end
	end
end

