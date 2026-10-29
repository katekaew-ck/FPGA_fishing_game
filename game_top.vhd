library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity game_top is
    port (
        clk          : in  std_logic;
        reset_button : in  std_logic;
        uart_rx      : in  std_logic;
        vga_r        : out std_logic_vector(3 downto 0);
        vga_g        : out std_logic_vector(3 downto 0);
        vga_b        : out std_logic_vector(3 downto 0);
        vga_hsync    : out std_logic;
        vga_vsync    : out std_logic
    );
end entity game_top;

architecture rtl of game_top is
    signal rx_data : std_logic_vector(7 downto 0);
    signal rx_byte_valid, rx_frame_error : std_logic;
    signal remote_position : unsigned(15 downto 0);
    signal remote_left, remote_right, packet_valid : std_logic;
    signal left_held, right_held, start_pulse : std_logic;
    signal left_press, right_press : std_logic;
    signal reel_delta : signed(15 downto 0);
    signal reel_valid : std_logic;
    signal frame_tick, video_active : std_logic;
    signal pixel_x, pixel_y : unsigned(9 downto 0);
    signal time_up, init_game, playing : std_logic;
    signal state_code : std_logic_vector(1 downto 0);
    signal remaining_seconds : unsigned(6 downto 0);
    signal hook_x, hook_y : unsigned(9 downto 0);
    signal fish_x_bus, fish_y_bus : std_logic_vector(49 downto 0);
    signal fish_kind_bus : std_logic_vector(9 downto 0);
    signal fish_dir_bus, fish_visible : std_logic_vector(4 downto 0);
    signal held_active : std_logic;
    signal held_kind : std_logic_vector(1 downto 0);
    signal boot_x, boot_y, eel_x, eel_y : unsigned(9 downto 0);
    signal stunned : std_logic;
    signal score : unsigned(9 downto 0);
begin
    uart_receiver : entity work.uart_rx_core
        generic map (CLK_HZ => 50_000_000, BAUD_RATE => 115_200)
        port map (clk => clk, reset => reset_button, rx_in => uart_rx,
                  data_out => rx_data, byte_valid => rx_byte_valid,
                  frame_error => rx_frame_error);

    controller_packet_parser : entity work.packet_parser
        port map (clk => clk, reset => reset_button,
                  byte_data => rx_data, byte_valid => rx_byte_valid,
                  frame_error => rx_frame_error,
                  position_out => remote_position,
                  left_pressed => remote_left,
                  right_pressed => remote_right,
                  packet_valid => packet_valid);

    player_input : entity work.input_manager
        port map (clk => clk, reset => reset_button,
                  packet_valid => packet_valid,
                  remote_position => remote_position,
                  remote_left => remote_left, remote_right => remote_right,
                  frame_tick => frame_tick,
                  left_held => left_held, right_held => right_held,
                  start_pulse => start_pulse,
                  left_press => left_press, right_press => right_press,
                  reel_delta => reel_delta, reel_valid => reel_valid);

    game_fsm : entity work.game_controller
        port map (clk => clk, reset => reset_button,
                  start_pulse => start_pulse,
                  left_press => left_press, right_press => right_press,
                  time_up => time_up, init_game => init_game,
                  playing => playing, state_code => state_code);

    timer_inst : entity work.game_timer
        generic map (CLK_HZ => 50_000_000, GAME_SECONDS => 60)
        port map (clk => clk, reset => reset_button,
                  init_game => init_game, playing => playing,
                  remaining_seconds => remaining_seconds,
                  time_up => time_up);

    game_data : entity work.game_datapath
        port map (
            clk => clk, reset => reset_button, init_game => init_game,
            playing => playing,
            left_held => left_held, right_held => right_held,
            reel_delta => reel_delta, reel_valid => reel_valid,
            hook_x => hook_x, hook_y => hook_y,
            fish_x_bus => fish_x_bus, fish_y_bus => fish_y_bus,
            fish_kind_bus => fish_kind_bus, fish_dir_bus => fish_dir_bus,
            fish_visible => fish_visible, held_active => held_active,
            held_kind => held_kind,
            boot_x => boot_x, boot_y => boot_y,
            eel_x => eel_x, eel_y => eel_y,
            stunned => stunned, score => score);

    video_timing : entity work.vga_timing
        port map (clk => clk, reset => reset_button,
                  pixel_x => pixel_x, pixel_y => pixel_y,
                  video_active => video_active, frame_tick => frame_tick,
                  hsync => vga_hsync, vsync => vga_vsync);

    video_renderer : entity work.renderer
        port map (
            pixel_x => pixel_x, pixel_y => pixel_y,
            video_active => video_active, state_code => state_code,
            hook_x => hook_x, hook_y => hook_y,
            fish_x_bus => fish_x_bus, fish_y_bus => fish_y_bus,
            fish_kind_bus => fish_kind_bus, fish_dir_bus => fish_dir_bus,
            fish_visible => fish_visible,
            held_active => held_active, held_kind => held_kind,
            boot_x => boot_x, boot_y => boot_y,
            eel_x => eel_x, eel_y => eel_y, stunned => stunned,
            score => score, remaining_seconds => remaining_seconds,
            red_out => vga_r, green_out => vga_g, blue_out => vga_b);
end architecture;
