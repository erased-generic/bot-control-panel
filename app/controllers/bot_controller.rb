class BotController < ApplicationController
  include TokenAuthentication

  LOG_FILE = Rails.root.join("log", "dashboard.log")

  def self.execute_and_log(command)
    output = `#{command}`
    File.open(LOG_FILE, "a") { |f| f.puts("[#{Time.now}] $ #{command}\n#{output.strip}") }
    output
  end

  def dashboard
  end

  def self.bot_ecosystem
    "#{APP_CONFIG['ecosystem_config']}"
  end

  def self.bot_dir
    "#{APP_CONFIG['bot_dir']}"
  end

  def self.bot_name
    "#{APP_CONFIG['bot_name']}"
  end

  def self.bot_ecosystem_command(cmd)
    "pm2 --cwd \"#{bot_dir}\" #{cmd} \"#{bot_ecosystem}\""
  end

  def self.bot_rebuild_command
    "npm --prefix \"#{bot_dir}\" install && npm --prefix \"#{bot_dir}\" run build && npm --prefix \"#{bot_dir}\" run data"
  end

  def exec_bg(shell_cmd)
    pid = Process.fork { BotController.execute_and_log(shell_cmd) }
    Process.detach(pid)
  end

  def control
    command = params[:command]

    shell_cmd = case command
    when 'start'
      "#{BotController.bot_rebuild_command} && #{BotController.bot_ecosystem_command('start')}"
    when 'stop'
      BotController.bot_ecosystem_command('stop')
    when 'update'
      "#{BotController.bot_ecosystem_command('stop')} && git -C \"#{BotController.bot_dir}\" pull --recurse-submodules && #{BotController.bot_rebuild_command} && #{BotController.bot_ecosystem_command('start')}"
    end

    exec_bg(shell_cmd)

    respond_to do |format|
      format.js
      format.html { redirect_to dashboard_path(token: params[:token]) }
    end
  end

  def start
    shell_cmd = "#{BotController.bot_rebuild_command} && #{BotController.bot_ecosystem_command('start')}"
    exec_bg(shell_cmd)
  end

  STATUS2EMOJI = {
    "launching" => "🟡",
    "online" => "🟢",
    "errored" => "⛔",
    "stopping" => "🟠",
    "stopped" => "🔴"
  }

  def pretty_interval(interval)
    interval.parts.map do |key, value|
      "#{value.to_i} #{key}"
    end.join(' ')
  end

  def status
    json_all_info = JSON.parse(`#{BotController.bot_ecosystem_command('jlist')}`)
      .find { |app| app["name"] == BotController.bot_name }
    if json_all_info.nil?
      render json: {}
      return
    end
    json_info = {
      name: json_all_info["name"],
      pid: json_all_info["pid"],
      status: json_all_info["pm2_env"]["status"],
      revision: json_all_info["pm2_env"]["env"]["GIT_COMMIT"],
      uptime: pretty_interval(ActiveSupport::Duration.build(Time.current - Time.at(0, json_all_info["pm2_env"]["pm_uptime"], :millisecond))),
      restart_time: json_all_info["pm2_env"]["restart_time"],
    }
    if json_info[:status] != "online" then
      json_info[:uptime] = "0"
    end
    emoji = STATUS2EMOJI[json_info[:status]] || "❓"
    json_info[:status] = "#{emoji} #{json_info[:status]}"
    render json: json_info
  end

  BOT_LOGS_LINES = 10
  DASHBOARD_LOGS_LINES = 50

  def logs
    logs = `pm2 logs #{BotController.bot_name} --nostream --lines #{BOT_LOGS_LINES}`
    dashboard_logs = `tail -n #{DASHBOARD_LOGS_LINES} #{LOG_FILE}`
    render json: { logs: logs, dashboard_logs: dashboard_logs }
  end
end
