type audio_bitrate =
  | ABR_64kbps
  | ABR_96kbps

type quality_level =
  | QL_1_3
  | QL_2_1
  | QL_3_1
  | QL_3_2

type max_bitrate =
  | MBR_192kbps
  | MBR_500kbps
  | MBR_1mbps
  | MBR_2mbps

type buffer_size =
  | BS_1M
  | BS_2M
  | BS_3M
  | BS_6M

type frame_rate =
  | FR_10
  | FR_24

type gop_length =
  | GL_30
  | GL_72

type frame_size =
  | FS_380x180
  | FS_420x270
  | FS_640x360
  | FS_1280x720

type encoding_options =
    audio_bitrate
    * quality_level
    * max_bitrate
    * buffer_size
    * frame_rate
    * gop_length
    * frame_size

type input_file = string

type output_dir = string

type execution_log = string

type error = execution_log * Unix.process_status

type callback = (execution_log, error) result -> unit Lwt.t

type t

val create : unit -> t Lwt.t

val schedule :
    t
    -> input_file
    -> output_dir
    -> encoding_options list
    -> callback
    -> unit Lwt.t
