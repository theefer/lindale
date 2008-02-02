#!/usr/bin/ruby

require 'models/mediaitemmodel.rb'


class PlaylistModel < MediaItemModel

  CURRENT_ROLE = MediaItemModel::USER_ROLE + 1

  slots 'update_position(int, int)', 'reset_playlist()'

  def initialize(xc, cache)
    super

    @filter_ids = nil

    connect(@cache, SIGNAL('position_updated(int, int)'),
            self, SLOT('update_position(int, int)'))
    connect(@cache, SIGNAL('playlist_refreshed()'),
            self, SLOT('reset_playlist()'))
    connect(@cache, SIGNAL('playlist_entry_inserted(int, int)'),
            self, SLOT('insert_id(int, int)'))
    connect(@cache, SIGNAL('playlist_entry_removed(int)'),
            self, SLOT('remove_at(int)'))
  end


  def update_position(old, new)
    item(old).setData(Qt::Variant.new(false), CURRENT_ROLE) if hasIndex(old, 0)
    item(new).setData(Qt::Variant.new(true),  CURRENT_ROLE) if hasIndex(new, 0)
  end

  def reset_playlist
    clear
    @cache.playlist_entries.each {|id| append_id(id)}
  end

  # FIXME: better filtering would simply 'hide' non-matching rows
  def filter(coll)
    @xc.coll_query_ids(coll) do |res|
      @filter_ids = res.value

      clear
      (@cache.playlist_entries & @filter_ids).each do |id|
        append_id(id)
      end
    end
  end

  def clear_filter
    @filter_ids = nil
    reset_playlist
  end
end
