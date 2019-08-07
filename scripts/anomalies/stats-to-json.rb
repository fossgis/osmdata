#!/usr/bin/ruby
#
#  stats-to-json.rb DATABASE
#

require 'json'
require 'sqlite3'

filename = ARGV[0]

db = SQLite3::Database.new(filename, { :readonly => true })
db.results_as_hash = true

datahash = {}

db.execute('SELECT * FROM stats ORDER BY date, key') do |row|
    date = row['date'].sub(/T.*$/, '')
    if !datahash[date]
        datahash[date] = {};
    end
    datahash[date][row['key']] = row['value']
end

data = []

datahash.keys.sort.each do |date|
    data << [date, datahash[date]]
end

puts JSON.pretty_generate(data)

