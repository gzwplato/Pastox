unit ToxCore;

{$macro on}
{$mode objfpc}{$H+}
{$DEFINE TOXFUNC:=cdecl; external LIBTOXCORE}

{$I common/toxdefs.inc}

interface

uses
  Classes, SysUtils, ctypes;

const
  LIBTOXCORE = {$IFDEF Unix}'libtoxcore.so'{$ENDIF};

type
  TTox = Pointer;

type
  {****************************************************************************
   *
   * :: Global enumerations
   *
   ****************************************************************************}

  {**
   * Represents the possible statuses a client can have.
   *}
  TOX_USER_STATUS =
  (
      {**
       * User is online and available.
       *}
      TOX_USER_STATUS_NONE,

      {*
       * User is away. Clients can set this e.g. after a user defined
       * inactivity time.
       *}
      TOX_USER_STATUS_AWAY,

      {*
       * User is busy. Signals to other clients that this client does not
       * currently wish to communicate.
       *}
      TOX_USER_STATUS_BUSY
  );


  {**
   * Represents message types for tox_friend_send_message and group chat
   * messages.
   *}
  TOX_MESSAGE_TYPE =
  (
      {**
       * Normal text message. Similar to PRIVMSG on IRC.
      *}
      TOX_MESSAGE_TYPE_NORMAL,

      {**
       * A message describing an user action. This is similar to /me (CTCP ACTION)
       * on IRC.
      *}
      TOX_MESSAGE_TYPE_ACTION
  );

  {****************************************************************************
   *
   * :: Startup options
   *
   ****************************************************************************}

  {**
   * Type of proxy used to connect to TCP relays.
   *}
  TOX_PROXY_TYPE =
  (
      {**
       * Don't use a proxy.
       *}
      TOX_PROXY_TYPE_NONE,

      {**
       * HTTP proxy using CONNECT.
       *}
      TOX_PROXY_TYPE_HTTP,

      {**
       * SOCKS proxy for simple socket pipes.
       *}
      TOX_PROXY_TYPE_SOCKS5
  );

  {**
   * Type of savedata to create the Tox instance from.
   *}
  TOX_SAVEDATA_TYPE =
  (
      {**
       * No savedata.
       *}
      TOX_SAVEDATA_TYPE_NONE,

      {**
       * Savedata is one that was obtained from tox_get_savedata
       *}
      TOX_SAVEDATA_TYPE_TOX_SAVE,

      {**
       * Savedata is a secret key of length TOX_SECRET_KEY_SIZE
       *}
      TOX_SAVEDATA_TYPE_SECRET_KEY
  );

 {**
  * This struct contains all the startup options for Tox. You can either allocate
  * this object yourself, and pass it to tox_options_default, or call
  * tox_options_new to get a new default options object.
  *}
  Tox_Options = packed record
    ipv6, udp                  : cbool;
    proxy_type                 : TOX_PROXY_TYPE;
    proxy_host                 : pcchar;
    proxy_port, start_port,
     end_port, tcp_port        : cuint16;
    savedata_type              : TOX_SAVEDATA_TYPE;
    savedata_data              : pcuint8;
    savedata_length            : csize_t;
  end;
  PTox_Options = ^Tox_Options;

 {**
 * Initialises a Tox_Options object with the default options.
 *
 * The result of this function is independent of the original options. All
 * values will be overwritten, no values will be read (so it is permissible
 * to pass an uninitialised object).
 *
 * If options is NULL, this function has no effect.
 *
 * @param options An options object to be filled with default options.
 *}

procedure tox_options_default (options: PTox_Options); TOXFUNC;
{**
 * Allocates a new Tox_Options object and initialises it with the default
 * options. This function can be used to preserve long term ABI compatibility by
 * giving the responsibility of allocation and deallocation to the Tox library.
 *
 * Objects returned from this function must be freed using the tox_options_free
 * function.
 *
 * @return A new Tox_Options object with default options or NULL on failure.
 *}
function tox_options_new(error: coff_t = 0): PTox_Options; TOXFUNC;
{**
 * Releases all resources associated with an options objects.
 *
 * Passing a pointer that was not returned by tox_options_new results in
 * undefined behaviour.
 *}
procedure tox_options_free(options: PTox_Options); TOXFUNC;

type
  {****************************************************************************
   *
   * :: Creation and destruction
   *
   ****************************************************************************}

  TOX_ERR_NEW =
  (
      TOX_ERR_NEW_OK,
      TOX_ERR_NEW_NULL,
      TOX_ERR_NEW_MALLOC,
      TOX_ERR_NEW_PORT_ALLOC,
      TOX_ERR_NEW_PROXY_BAD_TYPE,
      TOX_ERR_NEW_PROXY_BAD_HOST,
      TOX_ERR_NEW_PROXY_BAD_PORT,
      TOX_ERR_NEW_PROXY_NOT_FOUND,
      TOX_ERR_NEW_LOAD_ENCRYPTED,
      TOX_ERR_NEW_LOAD_BAD_FORMAT
  );
  PTOX_ERR_NEW = ^TOX_ERR_NEW;

{**
 * @brief Creates and initialises a new Tox instance with the options passed.
 *
 * This function will bring the instance into a valid state. Running the event
 * loop with a new instance will operate correctly.
 *
 * If loading failed or succeeded only partially, the new or partially loaded
 * instance is returned and an error code is set.
 *
 * @param options An options object as described above. If this parameter is
 *   NULL, the default options are used.
 *
 * @see tox_iterate for the event loop.
 *
 * @return A new Tox instance pointer on success or NULL on failure.
 *}
function tox_new(options: PTox_Options; error: PTOX_ERR_NEW): TTox;
                                                            TOXFUNC;

{**
 * Releases all resources associated with the Tox instance and disconnects from
 * the network.
 *
 * After calling this function, the Tox pointer becomes invalid. No other
 * functions can be called, and the pointer value can no longer be read.
 *}
procedure tox_kill(tox: TTox); TOXFUNC;

{**
 * Calculates the number of bytes required to store the tox instance with
 * tox_get_savedata. This function cannot fail. The result is always greater
 * than 0.
 *
 * @see threading for concurrency implications.
 *}
function tox_get_savedata_size(tox: TTOX): csize_t; TOXFUNC;

{**
 * Store all information associated with the tox instance to a byte array.
 *
 * @param data A memory region large enough to store the tox instance data.
 *   Call tox_get_savedata_size to find the number of bytes required. If this
 *   parameter is NULL, this function has no effect.
 *}
procedure tox_get_savedata(tox: TTox; savedata: pcuint8); TOXFUNC;

{******************************************************************************
 *
 * :: Connection lifecycle and event loop
 *
 ******************************************************************************}

type
  TOX_ERR_BOOTSTRAP =
  (
      {**
       * The function returned successfully.
       *}
      TOX_ERR_BOOTSTRAP_OK,

      {**
       * One of the arguments to the function was NULL when it was not expected.
       *}
      TOX_ERR_BOOTSTRAP_NULL,

      {**
       * The address could not be resolved to an IP address, or the IP address
       * passed was invalid.
       *}
      TOX_ERR_BOOTSTRAP_BAD_HOST,

      {**
       * The port passed was invalid. The valid port range is (1, 65535).
       *}
      TOX_ERR_BOOTSTRAP_BAD_PORT
  );
  PTOX_ERR_BOOTSTRAP = ^TOX_ERR_BOOTSTRAP;

{**
 * Sends a "get nodes" request to the given bootstrap node with IP, port, and
 * public key to setup connections.
 *
 * This function will attempt to connect to the node using UDP. You must use
 * this function even if Tox_Options.udp_enabled was set to false.
 *
 * @param address The hostname or IP address (IPv4 or IPv6) of the node.
 * @param port The port on the host on which the bootstrap Tox instance is
 *   listening.
 * @param public_key The long term public key of the bootstrap node
 *   (TOX_PUBLIC_KEY_SIZE bytes).
 * @return true on success.
 *}
function tox_bootstrap(tox: TTox; address: pcchar; port: cuint16;
                       public_key: pcuint8; error: TOX_ERR_BOOTSTRAP): cbool;
                                                                       TOXFUNC;

{**
 * Adds additional host:port pair as TCP relay.
 *
 * This function can be used to initiate TCP connections to different ports on
 * the same bootstrap node, or to add TCP relays without using them as
 * bootstrap nodes.
 *
 * @param address The hostname or IP address (IPv4 or IPv6) of the TCP relay.
 * @param port The port on the host on which the TCP relay is listening.
 * @param public_key The long term public key of the TCP relay
 *   (TOX_PUBLIC_KEY_SIZE bytes).
 * @return true on success.
 *}
function tox_add_tcp_relay(tox: TTox; address: pcchar; port: cuint16;
                           public_key: pcuint8;
                           error: PTOX_ERR_BOOTSTRAP): cbool; TOXFUNC;

{**
 * Protocols that can be used to connect to the network or friends.
 *}
type
  TOX_CONNECTION =
  (
      {**
       * There is no connection. This instance, or the friend the state change is
       * about, is now offline.
       *}
      TOX_CONNECTION_NONE,

      {**
       * A TCP connection has been established. For the own instance, this means it
       * is connected through a TCP relay, only. For a friend, this means that the
       * connection to that particular friend goes through a TCP relay.
       *}
      TOX_CONNECTION_TCP,

      {**
       * A UDP connection has been established. For the own instance, this means it
       * is able to send UDP packets to DHT nodes, but may still be connected to
       * a TCP relay. For a friend, this means that the connection to that
       * particular friend was built using direct UDP packets.
       *}
      TOX_CONNECTION_UDP
  );

{**
 * Return whether we are connected to the DHT. The return value is equal to the
 * last value received through the `self_connection_status` callback.
 *}
function tox_self_get_connection_status(tox: TTox): TOX_CONNECTION; TOXFUNC;

{**
 * @param ConnectionStatus Whether we are connected to the DHT.
 *}
type
  TProcSelfConnectionStatus = procedure(Tox: TTox; ConnectionStatus: TOX_CONNECTION; UserData: Pointer); cdecl;

{**
 * Set the callback for the `self_connection_status` event. Pass NULL to unset.
 *
 * This event is triggered whenever there is a change in the DHT connection
 * state. When disconnected, a client may choose to call tox_bootstrap again, to
 * reconnect to the DHT. Note that this state may frequently change for short
 * amounts of time. Clients should therefore not immediately bootstrap on
 * receiving a disconnect.
 *
 * TODO: how long should a client wait before bootstrapping again?
 *}
procedure tox_callback_self_connection_status(tox: TTox; callback: TProcSelfConnectionStatus; user_data: Pointer); TOXFUNC;

{**
 * Return the time in milliseconds before tox_iterate() should be called again
 * for optimal performance.
 *}
function tox_iteration_interval(tox: TTox): cuint32; TOXFUNC;

{**
 * The main loop that needs to be run in intervals of tox_iteration_interval()
 * milliseconds.
 *}
procedure tox_iterate(tox: TTox); TOXFUNC;

{*******************************************************************************
 *
 * :: Internal client information (Tox address/id)
 *
 ******************************************************************************}

{**
 * Writes the Tox friend address of the client to a byte array. The address is
 * not in human-readable format. If a client wants to display the address,
 * formatting is required.
 *
 * @param address A memory region of at least TOX_ADDRESS_SIZE bytes. If this
 *   parameter is NULL, this function has no effect.
 * @see TOX_ADDRESS_SIZE for the address format.
 *}
procedure tox_self_get_address(tox: TTox; address: pcuint8); TOXFUNC;

{**
 * Set the 4-byte nospam part of the address.
 *
 * @param nospam Any 32 bit unsigned integer.
 *}
procedure tox_self_set_nospam(tox: TTox; nospam: cuint32); TOXFUNC;

{**
 * Get the 4-byte nospam part of the address.
 *}
function tox_self_get_nospam(tox: TTox): cuint32; TOXFUNC;

{**
 * Copy the Tox Public Key (long term) from the Tox object.
 *
 * @param public_key A memory region of at least TOX_PUBLIC_KEY_SIZE bytes. If
 *   this parameter is NULL, this function has no effect.
 *}
procedure tox_self_get_public_key(tox: TTox; public_key: pcuint8); TOXFUNC;

{**
 * Copy the Tox Secret Key from the Tox object.
 *
 * @param secret_key A memory region of at least TOX_SECRET_KEY_SIZE bytes. If
 *   this parameter is NULL, this function has no effect.
 *}
procedure tox_self_get_secret_key(tox: TTox; secret_key: pcuint8); TOXFUNC;

{*******************************************************************************
 *
 * :: User-visible client information (nickname/status)
 *
 ******************************************************************************}

type
  {**
   * Common error codes for all functions that set a piece of user-visible
   * client information.
   *}
  TOX_ERR_SET_INFO =
  (
      {**
       * The function returned successfully.
      *}
      TOX_ERR_SET_INFO_OK,

      {**
       * One of the arguments to the function was NULL when it was not expected.
      *}
      TOX_ERR_SET_INFO_NULL,

      {**
       * Information length exceeded maximum permissible size.
      *}
      TOX_ERR_SET_INFO_TOO_LONG
  );
  PTOX_ERR_SET_INFO = ^TOX_ERR_SET_INFO;

{**
 * Set the nickname for the Tox client.
 *
 * Nickname length cannot exceed TOX_MAX_NAME_LENGTH. If length is 0, the name
 * parameter is ignored (it can be NULL), and the nickname is set back to empty.
 *
 * @param name A byte array containing the new nickname.
 * @param length The size of the name byte array.
 *
 * @return true on success.
 *}
function tox_self_set_name(tox: TTox; name: pcuint8; length: csize_t;
                           error: PTOX_ERR_SET_INFO): cbool; TOXFUNC;

{**
 * Return the length of the current nickname as passed to tox_self_set_name.
 *
 * If no nickname was set before calling this function, the name is empty,
 * and this function returns 0.
 *
 * @see threading for concurrency implications.
 *}
function tox_self_get_name_size(tox: TTox): csize_t; TOXFUNC;

{**
 * Write the nickname set by tox_self_set_name to a byte array.
 *
 * If no nickname was set before calling this function, the name is empty,
 * and this function has no effect.
 *
 * Call tox_self_get_name_size to find out how much memory to allocate for
 * the result.
 *
 * @param name A valid memory location large enough to hold the nickname.
 *   If this parameter is NULL, the function has no effect.
 *}
procedure tox_self_get_name(tox: TTox; name: pcuint8); TOXFUNC;

{**
 * Set the client's status message.
 *
 * Status message length cannot exceed TOX_MAX_STATUS_MESSAGE_LENGTH. If
 * length is 0, the status parameter is ignored (it can be NULL), and the
 * user status is set back to empty.
 *}
function tox_self_set_status_message(tox: TTox; message: pcuint8;
                           length: csize_t;
                           error: PTOX_ERR_SET_INFO): cbool; TOXFUNC;

{**
 * Return the length of the current status message as passed to tox_self_set_status_message.
 *
 * If no status message was set before calling this function, the status
 * is empty, and this function returns 0.
 *
 * @see threading for concurrency implications.
 *}
function tox_self_get_status_message_size(tox: TTox): csize_t; TOXFUNC;

{**
 * Write the status message set by tox_self_set_status_message to a byte array.
 *
 * If no status message was set before calling this function, the status is
 * empty, and this function has no effect.
 *
 * Call tox_self_get_status_message_size to find out how much memory to allocate
 * for the result.
 *
 * @param status A valid memory location large enough to hold the status message.
 *   If this parameter is NULL, the function has no effect.
 *}
procedure tox_self_get_status_message(tox: TTox; status_message: pcuint8);
                                                                 TOXFUNC;

{**
 * Set the client's user status.
 *
 * @param user_status One of the user statuses listed in the enumeration above.
 *}
procedure tox_self_set_status(tox: TTox; status: TOX_USER_STATUS); TOXFUNC;

{**
 * Returns the client's user status.
 *}
function tox_self_get_status(tox: TTox): TOX_USER_STATUS; TOXFUNC;

{******************************************************************************
 *
 * :: Friend list management
 *
 ***************************************************************************** }

type
  TOX_ERR_FRIEND_ADD =
  (
      {*
       * The function returned successfully.
       *}
      TOX_ERR_FRIEND_ADD_OK,
      {*
       * One of the arguments to the function was NULL when it was not expected.
       *}
      TOX_ERR_FRIEND_ADD_NULL,
      {*
       * The length of the friend request message exceeded
       * TOX_MAX_FRIEND_REQUEST_LENGTH.
       *}
      TOX_ERR_FRIEND_ADD_TOO_LONG,
      {*
       * The friend request message was empty. This, and the TOO_LONG code will
       * never be returned from tox_friend_add_norequest.
       *}
      TOX_ERR_FRIEND_ADD_NO_MESSAGE,
      {*
       * The friend address belongs to the sending client.
       *}
      TOX_ERR_FRIEND_ADD_OWN_KEY,
      {*
       * A friend request has already been sent, or the address belongs to a friend
       * that is already on the friend list.
       *}
      TOX_ERR_FRIEND_ADD_ALREADY_SENT,
      {*
       * The friend address checksum failed.
       *}
      TOX_ERR_FRIEND_ADD_BAD_CHECKSUM,
      {*
       * The friend was already there, but the nospam value was different.
       *}
      TOX_ERR_FRIEND_ADD_SET_NEW_NOSPAM,
      {*
       * A memory allocation failed when trying to increase the friend list size.
       *}
      TOX_ERR_FRIEND_ADD_MALLOC
  );
  PTOX_ERR_FRIEND_ADD = ^TOX_ERR_FRIEND_ADD;

{**
 * Add a friend to the friend list and send a friend request.
 *
 * A friend request message must be at least 1 byte long and at most
 * TOX_MAX_FRIEND_REQUEST_LENGTH.
 *
 * Friend numbers are unique identifiers used in all functions that operate on
 * friends. Once added, a friend number is stable for the lifetime of the Tox
 * object. After saving the state and reloading it, the friend numbers may not
 * be the same as before. Deleting a friend creates a gap in the friend number
 * set, which is filled by the next adding of a friend. Any pattern in friend
 * numbers should not be relied on.
 *
 * If more than INT32_MAX friends are added, this function causes undefined
 * behaviour.
 *
 * @param address The address of the friend (returned by tox_self_get_address of
 * the friend you wish to add) it must be TOX_ADDRESS_SIZE bytes.
 * @param message The message that will be sent along with the friend request.
 * @param length The length of the data byte array.
 *
 * @return the friend number on success, UINT32_MAX on failure.
 *}

function tox_friend_add(tox: TTox; address: pcuint8; message: pcuint8;
                           length: csize_t;
                           error: PTOX_ERR_FRIEND_ADD): cuint32; TOXFUNC;

{**
 * Add a friend without sending a friend request.
 *
 * This function is used to add a friend in response to a friend request. If the
 * client receives a friend request, it can be reasonably sure that the other
 * client added this client as a friend, eliminating the need for a friend
 * request.
 *
 * This function is also useful in a situation where both instances are
 * controlled by the same entity, so that this entity can perform the mutual
 * friend adding. In this case, there is no need for a friend request, either.
 *
 * @param public_key A byte array of length TOX_PUBLIC_KEY_SIZE containing the
 * Public Key (not the Address) of the friend to add.
 *
 * @return the friend number on success, UINT32_MAX on failure.
 * @see tox_friend_add for a more detailed description of friend numbers.
 *}
function tox_friend_add_norequest(tox: TTox; public_key: pcuint8;
                           error: PTOX_ERR_FRIEND_ADD): cuint32; TOXFUNC;


type
  TOX_ERR_FRIEND_DELETE =
  (
    {*
     * Success.
     *}
    TOX_ERR_FRIEND_DELETE_OK,
    {*
     * There was no friend with the given friend number. No friends were deleted.
     *}
    TOX_ERR_FRIEND_DELETE_FRIEND_NOT_FOUND
  );
  PTOX_ERR_FRIEND_DELETE = ^TOX_ERR_FRIEND_DELETE;

{*
 * Remove a friend from the friend list.
 *
 * This does not notify the friend of their deletion. After calling this
 * function, this client will appear offline to the friend and no communication
 * can occur between the two.
 *
 * @param friend_number Friend number for the friend to be deleted.
 *
 * @return true on success.
 *}

function tox_friend_delete(tox: TTox; friend_number: cuint32;
                           error: PTOX_ERR_FRIEND_DELETE): cbool; TOXFUNC;

{******************************************************************************
 *
 * :: Friend list queries
 *
 ***************************************************************************** }

type
  TOX_ERR_FRIEND_BY_PUBLIC_KEY =
  (
    {*
     * The function returned successfully.
     *}
    TOX_ERR_FRIEND_BY_PUBLIC_KEY_OK,
    {*
     * One of the arguments to the function was NULL when it was not expected.
     *}
    TOX_ERR_FRIEND_BY_PUBLIC_KEY_NULL,
    {*
     * No friend with the given Public Key exists on the friend list.
     *}
    TOX_ERR_FRIEND_BY_PUBLIC_KEY_NOT_FOUND
  );
  PTOX_ERR_FRIEND_BY_PUBLIC_KEY = ^TOX_ERR_FRIEND_BY_PUBLIC_KEY;

{*
 * Return the friend number associated with that Public Key.
 *
 * @return the friend number on success, UINT32_MAX on failure.
 * @param public_key A byte array containing the Public Key.
 *}

function tox_friend_by_public_key(tox: TTox; public_key: pcuint8;
                           error:PTOX_ERR_FRIEND_BY_PUBLIC_KEY): cuint32;
                                                                 TOXFUNC;

{*
 * Checks if a friend with the given friend number exists and returns true if
 * it does.
  }
function tox_friend_exists(tox: TTox; friend_number: cuint32): cbool; TOXFUNC;

{*
 * Return the number of friends on the friend list.
 *
 * This function can be used to determine how much memory to allocate for
 * tox_self_get_friend_list.
 *}
function tox_self_get_friend_list_size(tox: TTox): csize_t; TOXFUNC;

{*
 * Copy a list of valid friend numbers into an array.
 *
 * Call tox_self_get_friend_list_size to determine the number of elements to allocate.
 *
 * @param list A memory region with enough space to hold the friend list. If
 *   this parameter is NULL, this function has no effect.
 *}
procedure tox_self_get_friend_list(tox: TTox; friend_list: pcuint32); TOXFUNC;

type
  TOX_ERR_FRIEND_GET_PUBLIC_KEY =
  (
     {*
      * The function returned successfully.
      *}
     TOX_ERR_FRIEND_GET_PUBLIC_KEY_OK,
     {*
      * No friend with the given number exists on the friend list.
      *}
     TOX_ERR_FRIEND_GET_PUBLIC_KEY_FRIEND_NOT_FOUND
  );
  PTOX_ERR_FRIEND_GET_PUBLIC_KEY = ^TOX_ERR_FRIEND_GET_PUBLIC_KEY;

{*
 * Copies the Public Key associated with a given friend number to a byte array.
 *
 * @param friend_number The friend number you want the Public Key of.
 * @param public_key A memory region of at least TOX_PUBLIC_KEY_SIZE bytes. If
 *   this parameter is NULL, this function has no effect.
 *
 * @return true on success.
 *}
function tox_friend_get_public_key(tox: TTox; friend_number: cuint32;
                           public_key: pcuint8;
                           error: PTOX_ERR_FRIEND_GET_PUBLIC_KEY): cbool;
                                                                   TOXFUNC;

type
  TOX_ERR_FRIEND_GET_LAST_ONLINE =
  (
    {*
     * The function returned successfully.
     *}
    TOX_ERR_FRIEND_GET_LAST_ONLINE_OK,
    {*
     * No friend with the given number exists on the friend list.
     *}
    TOX_ERR_FRIEND_GET_LAST_ONLINE_FRIEND_NOT_FOUND
  );
  PTOX_ERR_FRIEND_GET_LAST_ONLINE = ^TOX_ERR_FRIEND_GET_LAST_ONLINE;

{*
 * Return a unix-time timestamp of the last time the friend associated with a given
 * friend number was seen online. This function will return UINT64_MAX on error.
 *
 * @param friend_number The friend number you want to query.
 *}

function tox_friend_get_last_online(tox: TTox; friend_number: uint32;
                           error: PTOX_ERR_FRIEND_GET_LAST_ONLINE): cuint64;
                                                                    TOXFUNC;

{******************************************************************************
 *
 * :: Friend-specific state queries (can also be received through callbacks)
 *
 ******************************************************************************}
{*
 * Common error codes for friend state query functions.
 *}
type
  TOX_ERR_FRIEND_QUERY =
  (
    {*
     * The function returned successfully.
     *}
    TOX_ERR_FRIEND_QUERY_OK,
    {*
     * The pointer parameter for storing the query result (name, message) was
     * NULL. Unlike the `_self_` variants of these functions, which have no effect
     * when a parameter is NULL, these functions return an error in that case.
     *}
    TOX_ERR_FRIEND_QUERY_NULL,
    {*
     * The friend_number did not designate a valid friend.
     *}
    TOX_ERR_FRIEND_QUERY_FRIEND_NOT_FOUND
  );
  PTOX_ERR_FRIEND_QUERY = ^TOX_ERR_FRIEND_QUERY;

{*
 * Return the length of the friend's name. If the friend number is invalid, the
 * return value is unspecified.
 *
 * The return value is equal to the `length` argument received by the last
 * `friend_name` callback.
 *}

function tox_friend_get_name_size(tox: TTox; friend_number: cuint32; error: PTOX_ERR_FRIEND_QUERY): csize_t; TOXFUNC;

{*
 * Write the name of the friend designated by the given friend number to a byte
 * array.
 *
 * Call tox_friend_get_name_size to determine the allocation size for the `name`
 * parameter.
 *
 * The data written to `name` is equal to the data received by the last
 * `friend_name` callback.
 *
 * @param name A valid memory region large enough to store the friend's name.
 *
 * @return true on success.
 *}
function tox_friend_get_name(tox: TTox; friend_number: cuint32;
                             name: pcuint8; error: PTOX_ERR_FRIEND_QUERY)
                                            : cbool; TOXFUNC;

{*
 * CALLBACK
 *
 * @param FriendNumber The friend number of the friend whose name changed.
 * @param Name A byte array containing the same data as
 *   tox_friend_get_name would write to its `name` parameter.
 * @param Length A value equal to the return value of
 *   tox_friend_get_name_size.
 *}
type
  TProcFriendName = procedure(Tox: TTox; FriendNumber: cuint32; Name: pcuint8;
                              Length: csize_t;
                              UserData: Pointer); cdecl;

{*
 * Set the callback for the `friend_name` event. Pass NULL to unset.
 *
 * This event is triggered when a friend changes their name.
 *}
procedure tox_callback_friend_name(tox: TTox; callback: TProcFriendName;
                                   user_data: Pointer); TOXFUNC;

{*
 * Return the length of the friend's status message. If the friend number is
 * invalid, the return value is SIZE_MAX.
 *}
function tox_friend_get_status_message_size(tox: TTox; friend_number: cuint32;
                                            error: PTOX_ERR_FRIEND_QUERY):
                                            csize_t; TOXFUNC;

{*
 * Write the status message of the friend designated by the given friend number
 * to a byte array.
 *
 * Call tox_friend_get_status_message_size to determine the allocation size for
 * the `status_name` parameter.
 *
 * The data written to `status_message` is equal to the data received by the
 * last `FriendStatusMsg` callback.
 *
 * @param status_message A valid memory region large enough to store the
 *   friend's status message.
 *}
function tox_friend_get_status_message(tox: TTox; friend_number: cuint32;
                                       status_message: pcuint8;
                                       error: PTOX_ERR_FRIEND_QUERY): cbool;
                                                                      TOXFUNC;

{*
 * CALLBACK
 *
 * @param FriendNumber The friend number of the friend whose status message
 *   changed.
 * @param message A byte array containing the same data as
 *   tox_friend_get_status_message would write to its `status_message` parameter.
 * @param length A value equal to the return value of
 *   tox_friend_get_status_message_size.
 *}
type
  TProcFriendStatusMsg = procedure(Tox: TTox; FriendNumber: cuint32;
                                   Message: pcuint8; Length: csize_t;
                                   UserData: Pointer); cdecl;

{*
 * Set the callback for the `friend_status_message` event. Pass NULL to unset.
 *
 * This event is triggered when a friend changes their status message.
 *}
procedure tox_callback_friend_status_message(tox: TTox;
                                             callback: TProcFriendStatusMsg;
                                             user_data: Pointer); TOXFUNC;

{*
 * Return the friend's user status (away/busy/...). If the friend number is
 * invalid, the return value is unspecified.
 *
 * The status returned is equal to the last status received through the
 * `friend_status` callback.
 *}
function tox_friend_get_status(tox: TTox; friend_number: cuint32;
                               error: PTOX_ERR_FRIEND_QUERY): TOX_USER_STATUS;
                                                              TOXFUNC;

{*
 * CALLBACK
 *
 * @param friend_number The friend number of the friend whose user status
 *   changed.
 * @param status The new user status.
 *}
type
  TProcFriendStatus = procedure(Tox: TTox; FriendNumber: cuint32;
                                   Status: TOX_USER_STATUS;
                                   UserData: Pointer); cdecl;

{*
 * Set the callback for the `friend_status` event. Pass NULL to unset.
 *
 * This event is triggered when a friend changes their user status.
 *}
procedure tox_callback_friend_status(tox: TTox;
                                     callback: TProcFriendStatus;
                                     user_data: Pointer); TOXFUNC;

{*
 * Check whether a friend is currently connected to this client.
 *
 * The result of this function is equal to the last value received by the
 * `friend_connection_status` callback.
 *
 * @param friend_number The friend number for which to query the connection
 *   status.
 *
 * @return the friend's connection status as it was received through the
 *   `friend_connection_status` event.
 *}
function tox_friend_get_connection_status(tox: TTox;
                                          friend_number: cuint32;
                                          error: PTOX_ERR_FRIEND_QUERY)
                                            : TOX_CONNECTION; TOXFUNC;

{*
 * @param friend_number The friend number of the friend whose connection status
 *   changed.
 * @param connection_status The result of calling
 *   tox_friend_get_connection_status on the passed friend_number.
 *}
type
  TProcFriendConnStatus = procedure(Tox: TTox; FriendNumber: cuint32;
                                    ConnectionStatus: TOX_CONNECTION;
                                    UserData: Pointer); cdecl;

{*
 * Set the callback for the `friend_connection_status` event. Pass NULL to unset.
 *
 * This event is triggered when a friend goes offline after having been online,
 * or when a friend goes online.
 *
 * This callback is not called when adding friends. It is assumed that when
 * adding friends, their connection status is initially offline.
 *}
procedure tox_callback_friend_connection_status(tox: TTox;
                                                callback: TProcFriendConnStatus;
                                                user_data: Pointer); TOXFUNC;

{*
 * Check whether a friend is currently typing a message.
 *
 * @param friend_number The friend number for which to query the typing status.
 *
 * @return true if the friend is typing.
 * @return false if the friend is not typing, or the friend number was
 *   invalid. Inspect the error code to determine which case it is.
  *}
function tox_friend_get_typing(tox: TTox; friend_number: cuint32;
                               error: PTOX_ERR_FRIEND_QUERY): cbool; TOXFUNC;

{*
 * @param FriendNumber The friend number of the friend who started or stopped
 *   typing.
 * @param IsTyping The result of calling tox_friend_get_typing on the passed
 *   friend_number.
 *}
type
  TProcFriendTyping = procedure(Tox: TTox; FriendNumber: cuint32;
                                IsTyping: cbool; UserData: Pointer); cdecl;

{*
 * Set the callback for the `friend_typing` event. Pass NULL to unset.
 *
 * This event is triggered when a friend starts or stops typing.
 *}
procedure tox_callback_friend_typing(tox: TTox; callback: TProcFriendTyping;
                                     user_data: Pointer); TOXFUNC;

{******************************************************************************
 *
 * :: Sending private messages
 *
 ******************************************************************************}
type
  TOX_ERR_SET_TYPING =
  (
      {**
       * The function returned successfully.
       *}
      TOX_ERR_SET_TYPING_OK,
      {**
       * The friend number did not designate a valid friend.
       *}
      TOX_ERR_SET_TYPING_FRIEND_NOT_FOUND
  );
  PTOX_ERR_SET_TYPING = ^TOX_ERR_SET_TYPING;

{**
 * Set the client's typing status for a friend.
 *
 * The client is responsible for turning it on or off.
 *
 * @param friend_number The friend to which the client is typing a message.
 * @param typing The typing status. True means the client is typing.
 *
 * @return true on success.
 *}
function tox_self_set_typing(tox: TTox; friend_number: cuint32; typing: cbool;
                             error: PTOX_ERR_SET_TYPING): cbool; TOXFUNC;

type
  TOX_ERR_FRIEND_SEND_MESSAGE =
  (
      {**
       * The function returned successfully.
       *}
      TOX_ERR_FRIEND_SEND_MESSAGE_OK,
      {**
       * One of the arguments to the function was NULL when it was not expected.
       *}
      TOX_ERR_FRIEND_SEND_MESSAGE_NULL,
      {**
       * The friend number did not designate a valid friend.
       *}
      TOX_ERR_FRIEND_SEND_MESSAGE_FRIEND_NOT_FOUND,
      {**
       * This client is currently not connected to the friend.
       *}
      TOX_ERR_FRIEND_SEND_MESSAGE_FRIEND_NOT_CONNECTED,
      {**
       * An allocation error occurred while increasing the send queue size.
       *}
      TOX_ERR_FRIEND_SEND_MESSAGE_SENDQ,
      {**
       * Message length exceeded TOX_MAX_MESSAGE_LENGTH.
       *}
      TOX_ERR_FRIEND_SEND_MESSAGE_TOO_LONG,
      {**
       * Attempted to send a zero-length message.
       *}
      TOX_ERR_FRIEND_SEND_MESSAGE_EMPTY
  );
  PTOX_ERR_FRIEND_SEND_MESSAGE = ^TOX_ERR_FRIEND_SEND_MESSAGE;

{**
 * Send a text chat message to an online friend.
 *
 * This function creates a chat message packet and pushes it into the send
 * queue.
 *
 * The message length may not exceed TOX_MAX_MESSAGE_LENGTH. Larger messages
 * must be split by the client and sent as separate messages. Other clients can
 * then reassemble the fragments. Messages may not be empty.
 *
 * The return value of this function is the message ID. If a read receipt is
 * received, the triggered `friend_read_receipt` event will be passed this
 * message ID.
 *
 * Message IDs are unique per friend. The first message ID is 0. Message IDs are
 * incremented by 1 each time a message is sent. If UINT32_MAX messages were
 * sent, the next message ID is 0.
 *
 * @param type Message type (normal, action, ...).
 * @param friend_number The friend number of the friend to send the message to.
 * @param message A non-NULL pointer to the first element of a byte array
 *   containing the message text.
 * @param length Length of the message to be sent.
 *}
function tox_friend_send_message(tox: TTox; friend_number: cuint32;
                                 msgtype: TOX_MESSAGE_TYPE; message: pcuint8;
                                 length: csize_t;
                                 error: PTOX_ERR_FRIEND_SEND_MESSAGE)
                                            : cuint32; TOXFUNC;

{**
 * CALLBACK
 *
 * @param FriendNumber The friend number of the friend who received the message.
 * @param MessageID The message ID as returned from tox_friend_send_message
 *   corresponding to the message sent.
 *}

type
  TProcFriendReadReceipt = procedure(Tox: TTox; FriendNumber: cuint32;
                                     MessageID: cuint32;
                                     UserData: Pointer); cdecl;

{**
 * Set the callback for the `friend_read_receipt` event. Pass NULL to unset.
 *
 * This event is triggered when the friend receives the message sent with
 * tox_friend_send_message with the corresponding message ID.
 *}
procedure tox_callback_friend_read_receipt(tox: TTox;
                                           callback: TProcFriendReadReceipt;
                                           user_data: Pointer); TOXFUNC;

{******************************************************************************
 *
 * :: Receiving private messages and friend requests
 *
 ******************************************************************************}

{**
 * CALLBACK
 *
 * @param public_key The Public Key of the user who sent the friend request.
 * @param time_delta A delta in seconds between when the message was composed
 *   and when it is being transmitted. For messages that are sent immediately,
 *   it will be 0. If a message was written and couldn't be sent immediately
 *   (due to a connection failure, for example), the time_delta is an
 *   approximation of when it was composed.
 * @param message The message they sent along with the request.
 * @param length The size of the message byte array.
 *}
type
  TProcFriendRequest = procedure(Tox: TTox; PublicKey: pcuint8;
                                 Message: pcuint8; Length: csize_t;
                                 UserData: Pointer); cdecl;


{**
 * Set the callback for the `friend_request` event. Pass NULL to unset.
 *
 * This event is triggered when a friend request is received.
 *}
procedure tox_callback_friend_request(tox: TTox;
                                      callback: TProcFriendRequest;
                                      user_data: Pointer); TOXFUNC;

{**
 * CALLBACK
 *
 * @param friend_number The friend number of the friend who sent the message.
 * @param time_delta Time between composition and sending.
 * @param message The message data they sent.
 * @param length The size of the message byte array.
 *
 * @see friend_request for more information on time_delta.
 *}
type
TProcFriendMsg =  procedure(Tox: TTox; FriendNumber: cuint32;
                            MessageType: TOX_MESSAGE_TYPE; Message: pcuint8;
                            Length: csize_t; UserData: Pointer); cdecl;


{**
 * Set the callback for the `friend_message` event. Pass NULL to unset.
 *
 * This event is triggered when a message from a friend is received.
 *}
procedure tox_callback_friend_message(tox: TTox; callback: TProcFriendMsg;
                                      user_data: Pointer); TOXFUNC;

implementation

end.

