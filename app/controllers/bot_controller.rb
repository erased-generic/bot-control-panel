require 'socket'

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
    APP_CONFIG['ecosystem_config']
  end

  def self.bot_dir
    APP_CONFIG['bot_dir']
  end

  def self.bot_name
    APP_CONFIG['bot_name']
  end

  def self.bot_ecosystem_command(cmd)
    "pm2 --cwd \"#{bot_dir}\" #{cmd} \"#{bot_ecosystem}\""
  end

  def self.bot_rebuild_command
    "npm --prefix \"#{bot_dir}\" install && npm --prefix \"#{bot_dir}\" run build && npm --prefix \"#{bot_dir}\" run data"
  end

  def self.pm2_iface_socket
     APP_CONFIG['pm2_iface_sock']
  end

  def self.pm2_jlist(timeout_sec = 2)
    Timeout.timeout(timeout_sec) do
      UNIXSocket.open(BotController.pm2_iface_socket) do |socket|
        return JSON.parse(socket.read)
      end
    end
  rescue => e
    Rails.logger.error("pm2_iface error: #{e}")
    {}
  end

  def exec_bg(shell_cmd)
    Thread.new { BotController.execute_and_log(shell_cmd) }
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

  @@STATUS2EMOJI = {
    "launching" => "🟡",
    "online" => "🟢",
    "errored" => "⛔",
    "stopping" => "🟠",
    "stopped" => "🔴",
    "missing" => "💀"
  }

  def self.status2emoji(status)
    "#{@@STATUS2EMOJI[status] || '❓'} #{status}"
  end

  def pretty_interval(interval)
    interval.parts.map do |key, value|
      "#{value.to_i} #{key}"
    end.join(' ')
  end

  def status
    json_all_info = BotController.pm2_jlist
      .find { |app| app["name"] == BotController.bot_name }
    if json_all_info.nil?
      render json: {
        name: BotController.bot_name,
        status: BotController.status2emoji("missing")
      }
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
    json_info[:status] = BotController.status2emoji(json_info[:status])
    render json: json_info
  end

  BOT_LOGS_LINES = 10
  DASHBOARD_LOGS_LINES = 50

  def app_logs(json_all_info)
    if json_all_info.nil?
      return nil
    else
      pm_out_log_path = json_all_info.dig('pm2_env', 'pm_out_log_path')
      pm_err_log_path = json_all_info.dig('pm2_env', 'pm_err_log_path')
      if pm_out_log_path.nil? or pm_err_log_path.nil?
        return nil
      end
      err_log = `tail -n #{BOT_LOGS_LINES} #{pm_err_log_path}`
      out_log = `tail -n #{BOT_LOGS_LINES} #{pm_out_log_path}`
      return "stderr last 10 lines:\n#{err_log}\nstdout last 10 lines:\n#{out_log}"
    end
  end

  def logs
    output = BotController.pm2_jlist
    json_all_info = output
      .find { |app| app["name"] == BotController.bot_name }
    logs = app_logs(json_all_info) || "Failed to get app logs..."
    dashboard_logs = `tail -n #{DASHBOARD_LOGS_LINES} #{LOG_FILE}`
    render json: { logs: logs, dashboard_logs: dashboard_logs }
  end
end
