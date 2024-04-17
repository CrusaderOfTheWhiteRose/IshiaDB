# Performance

* get rid of page allocator in favor of fixed buffer one
* let every file to be open and store them into hash map
* use splice to transfer a huge amount of images (use queries)
* async does not work in this zig version, consider adding my own solution
* use ffmpeg's libraries instead of ffmpeg itself

# Queries

* add 2 more query types (d, DEFINE, define)
* to select and filter files
* to delete stuff

# Features

* add log file and more logging in general
* add arguments for header/body max size
* provide cache
* backups and archive
* add slots image that will be send back on error

# Roadmap

* overwiew thread pool's work one more time
* make extension for highlighting queries
* scaling (TiKV cluster?)
* add vector database to cluster files
* make the best way to request the files
* implement admin panel for the database

# Bugs

* using -Doptimize=ReleaseFast will cause a bug when it push half of the hash on db init. Some zig's bug with buffers?
* can not go with multiple requests from browser at the same time. Maybe some performance issues and browser closes the request? Get BrokenPipe and ClosedByPeer error if spam requests
* sometimes it can not find a hash if it's lenght is less then 10. Found it once, should make hash to be [10]u8 instead of []const u8
