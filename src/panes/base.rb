#!/usr/bin/ruby

require 'Qt4'


class Pane < Qt::Object

  # need to be redeclared in the child class!
  signals 'message(const QString&)', 'warning(const QString&)', 'error(const QString&)'

  # return the Qt::Widget of the pane, or nil if none
  def widget
    return nil
  end

  # execute the command
  def run(arguments, register_opts = nil)
    throw NotImplementedError.new
  end

  private
  def initialize(xc, cache)
    super()

    @xc = xc
    @cache = cache
  end
end
