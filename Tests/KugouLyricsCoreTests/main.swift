import Darwin

let tests: [(String, () async throws -> Void)] = [
    ("LRC metadata and timestamps", { try LRCParserTests().parsesMetadataMultipleTimestampsAndFractions() }),
    ("LRC malformed lines", { try LRCParserTests().skipsMalformedLinesAndEmptyText() }),
    ("LRC missing timestamps", { try LRCParserTests().rejectsTextWithoutTimedLyrics() }),
    ("KRC macOS decoding", { try KRCParserTests().decryptsMacKRCAndPreservesWordTiming() }),
    ("KRC zlib-wrapped decoding", { try KRCParserTests().decryptsZlibWrappedMacKRC() }),
    ("KRC invalid input", { try KRCParserTests().rejectsInvalidHeaderAndCompressedData() }),
    ("Lyrics color preference", { try LyricsColorPresetTests().restoresSavedSelectionAndDefaultsToWhite() }),
    ("Lyrics line boundaries", { try LyricsDocumentTests().lineIndexHandlesIntroBoundariesAndTail() }),
    ("Lyrics offset", { try LyricsDocumentTests().positiveOffsetDelaysLyrics() }),
    ("Track normalized metadata", { try TrackMatcherTests().acceptsNormalizedMetadataAndDuration() }),
    ("Track artist separators", { try TrackMatcherTests().normalizesArtistSeparators() }),
    ("Track mismatch rejection", { try TrackMatcherTests().rejectsWrongArtistOrDuration() }),
    ("AX current KuGou layout", { try KugouAXSnapshotParserTests().parsesCurrentKuGouButtonsAndIdentifiedTimeLabels() }),
    ("AX combined title fallback", { try KugouAXSnapshotParserTests().fallsBackToCombinedStaticTitle() }),
    ("AX missing duration", { try KugouAXSnapshotParserTests().rejectsMissingDuration() }),
    ("Playback initial pause", { try PlaybackSynchronizerTests().waitsForObservedMovementBeforePlaying() }),
    ("Playback interpolation and pause", { try PlaybackSynchronizerTests().interpolatesNormalTicksAndDetectsPause() }),
    ("Playback seek and track change", { try PlaybackSynchronizerTests().seekAndTrackChangeResetEstimate() }),
    ("Local KRC metadata lookup", { try LocalLyricsStoreTests().findsMatchingKRCFromMetadata() }),
    ("Local filename fallback", { try LocalLyricsStoreTests().rejectsWrongArtistAndUsesFilenameFallback() }),
    ("Local filename fallback for different embedded version", { try LocalLyricsStoreTests().usesMatchingFilenameWhenEmbeddedTitleHasDifferentVersion() }),
    ("LRCLIB matched lyrics", { try await LRCLIBClientTests().returnsMatchedSyncedLyrics() }),
    ("LRCLIB mismatch rejection", { try await LRCLIBClientTests().rejectsMismatchedTrack() }),
    ("LRCLIB missing synced lyrics", { try await LRCLIBClientTests().returnsNilForNotFoundOrPlainLyrics() }),
    ("Repository local priority", { try await LyricsRepositoryTests().prefersLocalLyrics() }),
    ("Repository online fallback", { try await LyricsRepositoryTests().fallsBackToOnlineLyrics() }),
    ("Repository manual override", { try await LyricsRepositoryTests().manualImportOverridesCachedSource() }),
    ("Lyrics three and five line windows", { try LyricsWindowTests().buildsThreeAndFiveLineWindows() }),
    ("Lyrics window boundaries", { try LyricsWindowTests().padsBoundariesAndLeavesIntroEmpty() }),
    ("Lyrics current word timing", { try LyricsWindowTests().tracksCurrentWordUsingLineRelativeTimingAndOffset() }),
    ("Lyrics continuous word groups", { try LyricsWindowTests().groupsContinuousWordsForWaveMotion() }),
    ("Lyrics current line progress", { try LyricsWindowTests().tracksCurrentLineProgressFromStartToEnd() }),
    ("MediaRemote timestamp progress", { try MediaRemotePlaybackTests().advancesPlayingProgressAndFreezesPausedProgress() }),
    ("MediaRemote repairs stale AX progress", { try MediaRemotePlaybackTests().replacesStaleAXProgressForTheSameTrack() }),
    ("MediaRemote missing or other track fallback", { try MediaRemotePlaybackTests().keepsAXForMissingOrMismatchedRemoteData() }),
    ("MediaRemote stale data rejection", { try MediaRemotePlaybackTests().rejectsRemoteProgressBeyondTheTrackDuration() }),
    ("MediaRemote minimized KuGou fallback", { try MediaRemotePlaybackTests().createsStandaloneStateOnlyForKuGou() }),
    ("MediaRemote invalid standalone metadata", { try MediaRemotePlaybackTests().rejectsStandaloneStateWithInvalidMetadata() })
]

var failures = 0
for (name, body) in tests {
    do {
        try await body()
        print("PASS \(name)")
    } catch {
        failures += 1
        print("FAIL \(name): \(error)")
    }
}
print("Executed \(tests.count) tests, \(failures) failed")
if failures > 0 { exit(1) }
