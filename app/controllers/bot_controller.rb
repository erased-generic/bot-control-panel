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
    @bots = BotController.bot_names
  end

  def self.bot_ecosystem(bot_name)
    APP_CONFIG['bots'][bot_name][:ecosystem_config]
  end

  def self.bot_dir(bot_name)
    APP_CONFIG['bots'][bot_name][:bot_dir]
  end

  def self.bot_name?(bot_name)
    APP_CONFIG['bots'].key?(bot_name)
  end

  def self.bot_names
    APP_CONFIG['bots'].map do |bot_name, _|
      bot_name
    end
  end

  def self.bot_ecosystem_command(bot_name, cmd)
    "pm2 --cwd \"#{bot_dir(bot_name)}\" #{cmd} \"#{bot_ecosystem(bot_name)}\""
  end

  def self.bot_rebuild_command(bot_name)
    "npm --prefix \"#{bot_dir(bot_name)}\" install && npm --prefix \"#{bot_dir(bot_name)}\" run build && npm --prefix \"#{bot_dir(bot_name)}\" run data"
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
    bot_name = params[:bot_name]
    if BotController.bot_name?(bot_name) then
      shell_cmd = case command
                  when 'start'
                    "#{BotController.bot_rebuild_command(bot_name)} && #{BotController.bot_ecosystem_command(bot_name, 'start')}"
                  when 'stop'
                    BotController.bot_ecosystem_command(bot_name, 'stop')
                  when 'update'
                    "#{BotController.bot_ecosystem_command(bot_name, 'stop')} && git -C \"#{BotController.bot_dir(bot_name)}\" pull --recurse-submodules && #{BotController.bot_rebuild_command(bot_name)} && #{BotController.bot_ecosystem_command(bot_name, 'start')}"
                  end

      exec_bg(shell_cmd)
    end

    respond_to do |format|
      format.js
      format.html { redirect_to dashboard_path(token: params[:token]) }
    end
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
    default_infos = BotController.bot_names.map do |bot_name|
      [bot_name, { status: BotController.status2emoji("missing") }]
    end.to_h
    all_infos = BotController.pm2_jlist.each_with_object(default_infos) do |app, acc|
      if BotController.bot_name?(app["name"]) then
        json_info = {
          status: app["pm2_env"]["status"],
          pid: app["pid"],
          revision: app["pm2_env"]["env"]["GIT_COMMIT"],
          uptime: pretty_interval(ActiveSupport::Duration.build(Time.current - Time.at(0, app["pm2_env"]["pm_uptime"], :millisecond))),
          restart_time: app["pm2_env"]["restart_time"],
        }
        if json_info[:status] != "online" then
          json_info[:uptime] = "0"
        end
        json_info[:status] = BotController.status2emoji(json_info[:status])
        acc[app["name"]] = json_info
      end
    end
    render json: all_infos
  end

  BOT_LOGS_LINES = 10
  DASHBOARD_LOGS_LINES = 50

  def app_logs(app)
    if app.nil?
      return nil
    else
      pm_out_log_path = app.dig('pm2_env', 'pm_out_log_path')
      pm_err_log_path = app.dig('pm2_env', 'pm_err_log_path')
      if pm_out_log_path.nil? or pm_err_log_path.nil?
        return nil
      end
      err_log = `tail -n #{BOT_LOGS_LINES} #{pm_err_log_path}`
      out_log = `tail -n #{BOT_LOGS_LINES} #{pm_out_log_path}`
      return "#{app["name"]} stderr last 10 lines:\n#{err_log}\n#{app["name"]} stdout last 10 lines:\n#{out_log}\n"
    end
  end

  def logs
    bot_logs = BotController.pm2_jlist
      .select do |app| BotController.bot_name?(app["name"]) end
      .map do |app| [app["name"], app_logs(app) || "Failed to get #{app["name"]} logs...\n\n"] end
      .to_h
    dashboard_logs = `tail -n #{DASHBOARD_LOGS_LINES} #{LOG_FILE}`
    render json: { logs: bot_logs, dashboard_logs: dashboard_logs }
  end
end
