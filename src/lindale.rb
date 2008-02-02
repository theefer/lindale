#!/usr/bin/ruby

require 'Qt4'
require 'xmmsclient/async'


class Lindale < Qt::Widget

  class Command
    attr_reader :query, :focus

    def initialize(target, opt, name)
      @target = target
      @option = opt
      @query  = name
      @focus  = :input
    end

    def has_widget?
      return ! widget.nil?
    end

    def widget
      return @target.widget
    end

    def run(args)
      @target.run(args, @option)
    end

    def save_query(query)
      @query = query
    end

    def save_focus(focus)
      @focus = focus
    end
  end


  slots 'run()', 'next_pane()', 'switch_focus()',
        'show_message(const QString&)', 'show_warning(const QString&)', 'show_error(const QString&)'

  def initialize()
    super()

    @status_bar_timeout = 2000

    @stack = Qt::StackedWidget.new
    @commands = Hash.new
    @panes = Array.new

    @cmd = Qt::LineEdit.new

    shortcut_tab = Qt::Shortcut.new(Qt::KeySequence.new("Tab"), self)
    shortcut_ctrltab = Qt::Shortcut.new(Qt::KeySequence.new("Ctrl+Tab"), self)
    shortcut_left = Qt::Shortcut.new(Qt::KeySequence.new("Ctrl+Left"), self)
    shortcut_right = Qt::Shortcut.new(Qt::KeySequence.new("Ctrl+Right"), self)

    connect(@cmd, SIGNAL('returnPressed()'), self, SLOT('run()'))

    connect(shortcut_tab, SIGNAL('activated()'), self, SLOT('switch_focus()'))
    connect(shortcut_ctrltab, SIGNAL('activated()'), self, SLOT('next_pane()'))
    connect(shortcut_left, SIGNAL('activated()'), self, SLOT('next_pane()'))
    connect(shortcut_right, SIGNAL('activated()'), self, SLOT('next_pane()'))

    layout = Qt::VBoxLayout.new
    layout.addWidget(@cmd)
    layout.addWidget(@stack)
    setLayout(layout)
  end

  def add_command(cmd, target, opt = nil)
    unless @panes.include?(target)
      # add widget to stack if exists
      unless target.widget.nil?
        @stack.addWidget(target.widget)
      end

      # connect status notifiers
      connect(target, SIGNAL('message(const QString&)'),
              self, SLOT('show_message(const QString&)'))
      connect(target, SIGNAL('warning(const QString&)'),
              self, SLOT('show_warning(const QString&)'))
      connect(target, SIGNAL('error(const QString&)'),
              self, SLOT('show_error(const QString&)'))
    end

    @commands[cmd] = Command.new(target, opt, cmd)
    @panes.push(target)
    self
  end

  def add_alias(cmd, *aliases)
    # FIXME: error unless @commands.key?(cmd)
    aliases.each do |alias_cmd|
      @commands[alias_cmd] = @commands[cmd]
    end
    self
  end

  def run()
    input = @cmd.text
    input.scan(/^(.*?)(?:\s+(.+)?)?$/) do ||
      cmd_str = $1
      command = @commands[cmd_str]

      if command.nil?
        show_error("invalid command: #{cmd_str}")
      else
        load_pane_with(command.widget) if command.has_widget?
        command.run($2)
      end
    end
  end

  def next_pane()
    load_pane((@stack.currentIndex + 1) % @stack.count)
  end

  def load_pane(new_index)
    save_pane_status
    @stack.setCurrentIndex(new_index)
    restore_pane_status
  end

  def load_pane_with(widget)
    save_pane_status
    @stack.setCurrentWidget(widget)
    restore_pane_status
  end

  # FIXME: cache current command

  # save query and focus
  def save_pane_status
    currw = @stack.currentWidget
    focus = if @cmd.hasFocus then :input else :pane end
    @commands.each do |key, cmd|
      if cmd.widget == currw
        cmd.save_query(@cmd.text)
        cmd.save_focus(focus)
        break
      end
    end
  end

  # restore query and focus
  def restore_pane_status
    currw = @stack.currentWidget
    @commands.each do |key, cmd|
      if cmd.widget == currw
        @cmd.setText(cmd.query)
        case cmd.focus
        when :input
          @cmd.setFocus(Qt::TabFocusReason)
        when :pane
          @stack.currentWidget.setFocus(Qt::TabFocusReason)
        end
        break
      end
    end
  end

  def switch_focus()
    if @cmd.hasFocus
      @stack.currentWidget.setFocus(Qt::TabFocusReason)
    else
      @cmd.setFocus(Qt::TabFocusReason)
    end
  end

  def show_message(m)
    parent.statusBar.showMessage(m, @status_bar_timeout)
  end
  def show_warning(m)
    # FIXME: change background color
    parent.statusBar.showMessage(m, @status_bar_timeout)
  end
  def show_error(m)
    # FIXME: change background color
    parent.statusBar.showMessage(m, @status_bar_timeout)
  end
end
