library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity controller_top is
    port (
        clk         : in  std_logic;
        reset_button : in std_logic;

        btn_left_n  : in  std_logic;
        btn_right_n : in  std_logic;

        enc_a       : in  std_logic;
        enc_b       : in  std_logic;

        uart_tx     : out std_logic
    );
end entity controller_top;

architecture rtl of controller_top is

    signal reset : std_logic;

    signal btn_left_sync  : std_logic;
    signal btn_right_sync : std_logic;
    signal enc_a_sync     : std_logic;
    signal enc_b_sync     : std_logic;

    signal left_pressed   : std_logic;
    signal right_pressed  : std_logic;

    signal encoder_step   : std_logic;
    signal encoder_dir    : std_logic;

    signal encoder_position : unsigned(15 downto 0);

    signal send_tick : std_logic;

    signal tx_data  : std_logic_vector(7 downto 0);
    signal tx_start : std_logic;
    signal tx_busy  : std_logic;
    signal tx_done  : std_logic;

    signal raw_inputs  : std_logic_vector(3 downto 0);
    signal sync_inputs : std_logic_vector(3 downto 0);

    signal packet_busy : std_logic;

    signal left_press_pulse    : std_logic;
    signal right_press_pulse   : std_logic;
    signal left_release_pulse  : std_logic;
    signal right_release_pulse : std_logic;
    signal encoder_invalid     : std_logic;

begin
    raw_inputs(3) <= btn_left_n;
    raw_inputs(2) <= btn_right_n;
    raw_inputs(1) <= enc_a;
    raw_inputs(0) <= enc_b;

    input_synchronizer : entity work.sync_2ff
        generic map (
            WIDTH => 4
        )
        port map (
            clk      => clk,
            reset    => reset,
            async_in => raw_inputs,
            sync_out => sync_inputs
        );

    btn_left_sync  <= sync_inputs(3);
    btn_right_sync <= sync_inputs(2);
    enc_a_sync     <= sync_inputs(1);
    enc_b_sync     <= sync_inputs(0);

    reset <= reset_button;

    debounce_left : entity work.button_debounce
        generic map (
            CLK_HZ      => 50_000_000,
            DEBOUNCE_MS => 10
        )
        port map (
            clk           => clk,
            reset         => reset,
            button_n      => btn_left_sync,
            pressed       => left_pressed,
            press_pulse   => left_press_pulse,
            release_pulse => left_release_pulse
        );

    debounce_right : entity work.button_debounce
        generic map (
            CLK_HZ      => 50_000_000,
            DEBOUNCE_MS => 10
        )
        port map (
            clk           => clk,
            reset         => reset,
            button_n      => btn_right_sync,
            pressed       => right_pressed,
            press_pulse   => right_press_pulse,
            release_pulse => right_release_pulse
        );

    rotary_decoder : entity work.quadrature_decoder
        port map (
            clk           => clk,
            reset         => reset,
            enc_a         => enc_a_sync,
            enc_b         => enc_b_sync,
            step_pulse    => encoder_step,
            direction     => encoder_dir,
            invalid_pulse => encoder_invalid
        );

    encoder_position_counter : entity work.position_counter
        generic map (
            WIDTH => 16
        )
        port map (
            clk          => clk,
            reset        => reset,
            step_pulse   => encoder_step,
            direction    => encoder_dir,
            position_out => encoder_position
        );

    packet_tick_generator : entity work.tick_generator
        generic map (
            CLK_HZ => 50_000_000,
            TICK_HZ => 100
        )
        port map (
            clk => clk,
            reset => reset,
            tick_out => send_tick
        );

    uart_transmitter : entity work.uart_tx_core
        generic map (
            CLK_HZ    => 50_000_000,
            BAUD_RATE => 115_200
        )
        port map (
            clk      => clk,
            reset    => reset,
            data_in  => tx_data,
            tx_start => tx_start,
            tx_out   => uart_tx,
            tx_busy  => tx_busy,
            tx_done  => tx_done
        );

    controller_packet_sender : entity work.packet_sender
        port map (
            clk           => clk,
            reset         => reset,

            send_tick     => send_tick,

            position_in   => encoder_position,
            left_pressed  => left_pressed,
            right_pressed => right_pressed,

            tx_busy       => tx_busy,
            tx_done       => tx_done,

            tx_data       => tx_data,
            tx_start      => tx_start,

            packet_busy   => packet_busy
        );

end architecture rtl;
