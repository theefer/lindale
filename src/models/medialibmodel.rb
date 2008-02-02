#!/usr/bin/ruby

require 'models/mediaitemmodel.rb'


class MedialibModel < MediaItemModel

  def initialize(xc, cache)
    super
  end

  def search(coll)
    @xc.coll_query_ids(coll) do |res|
      clear
      res.value.each {|id| append_id(id)}
    end
  end
end
