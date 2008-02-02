#!/usr/bin/ruby

require 'Qt4'
require 'xmmsclient/async'

require 'panes/base.rb'
require 'models/medialibmodel.rb'


# search matching media and display them as a list
class Search < Pane
  def initialize(xc, cache)
    super

    @mlib = Qt::ListView.new
    @results = MedialibModel.new(@xc, @cache)
    @mlib.setModel(@results)
    @mlib.setSelectionMode(Qt::AbstractItemView::ExtendedSelection)
    @mlib.setAlternatingRowColors(true)
  end

  def widget
    return @mlib
  end

  def run(arguments, register_opts = nil)
    # FIXME: show all?
    return if arguments.nil?

    coll = Xmms::Collection.parse(arguments)
    @results.search(coll)
  end
end
