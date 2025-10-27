# Jitsi Meet - Testing Guide

**Feature**: 001-jitsi-server
**Test Environment**: Production (meet.viljo.se)

## Pre-Testing Checklist

Ensure deployment completed successfully:

- [ ] Container 160 running: `pct status 160`
- [ ] Docker containers up: `pct exec 160 -- docker ps`
- [ ] Web accessible: `curl -I https://meet.viljo.se`
- [ ] DNS resolves: `dig meet.viljo.se +short`

## Test Plan

### Test 1: Anonymous Meeting Creation (Priority P1)

**User Story**: Team members need to quickly start video meetings without accounts.

**Acceptance Criteria**:
1. User enters meeting room name and joins immediately
2. Second user joins same room and they connect
3. Meeting URL can be shared for others to join

**Test Steps**:

1. Open browser to https://meet.viljo.se
2. Enter meeting name: "test-anonymous-meeting"
3. Allow camera/microphone when prompted
4. Verify video/audio preview shows

**Expected Result**: Successfully in meeting room with audio/video working

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes**:
```
_____________________________________
_____________________________________
_____________________________________
```

---

**Test Steps (Multi-User)**:

1. Open incognito/private window
2. Navigate to: https://meet.viljo.se/test-anonymous-meeting
3. Enter name: "Test User 2"
4. Join meeting

**Expected Result**: Both participants see each other, audio/video working

**Pass/Fail**: ☐ Pass ☐ Fail

---

### Test 2: Screen Sharing (Priority P2)

**User Story**: Participants need to share screens for presentations.

**Acceptance Criteria**:
1. User can select window/screen to share
2. Other participants see shared screen clearly
3. Sharing can be stopped and view returns to normal

**Test Steps**:

1. Join meeting from Test 1
2. Click "Share screen" button
3. Select a window or entire screen
4. Share for 30 seconds
5. Stop sharing

**Expected Result**:
- Screen sharing initiated successfully
- Other participant sees shared content
- Sharing stops cleanly

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes**:
```
_____________________________________
_____________________________________
```

---

### Test 3: Meeting Recording (Priority P3)

**User Story**: Hosts need to record meetings for documentation.

**Acceptance Criteria**:
1. Moderator can start recording
2. Recording continues through meeting
3. Recording file saved with proper naming

**Test Steps**:

1. Authenticate as moderator (see Test 4 first)
2. Start a new meeting
3. Click "Start recording"
4. Wait 60 seconds
5. Stop recording
6. Check recording saved:
   ```bash
   ssh root@192.168.1.3 "ls -lh /mnt/storage/jitsi-recordings/"
   ```

**Expected Result**:
- Recording starts without errors
- File saved to host storage
- File size reasonable (~MB for 1 minute)

**Pass/Fail**: ☐ Pass ☐ Fail

**Recording File**:
```
_____________________________________
```

---

### Test 4: SSO Authentication (Priority P4)

**User Story**: Users authenticate with GitLab credentials via Keycloak.

**Acceptance Criteria**:
1. Redirect to Keycloak for authentication
2. GitLab OAuth flow completes
3. Return to Jitsi with authenticated identity

**Test Steps**:

1. Open new private/incognito window
2. Navigate to: https://meet.viljo.se/secure-test-meeting
3. Click "I am the host" or similar moderator prompt
4. Should redirect to Keycloak login
5. Click "Sign in with GitLab" (or similar)
6. Authenticate with GitLab credentials
7. Should redirect back to Jitsi meeting

**Expected Result**:
- Redirect flow works smoothly
- Authenticated and returned to meeting
- Display name from GitLab profile

**Pass/Fail**: ☐ Pass ☐ Fail

**Notes**:
```
_____________________________________
_____________________________________
```

---

### Test 5: Moderator vs Guest Permissions

**User Story**: Authenticated users are moderators, anonymous are guests.

**Test Steps**:

1. Authenticated user (from Test 4) creates meeting
2. Anonymous user (incognito window) joins same meeting
3. Authenticated user verifies moderator controls:
   - [ ] Can mute other participants
   - [ ] Can remove participants
   - [ ] Can start recording
   - [ ] Can grant moderator to others
4. Anonymous user verifies guest limitations:
   - [ ] Cannot mute others
   - [ ] Cannot remove participants
   - [ ] Cannot start recording

**Expected Result**:
- Authenticated user has all moderator controls
- Anonymous user has limited controls

**Pass/Fail**: ☐ Pass ☐ Fail

---

### Test 6: Multi-Participant Performance

**Success Criteria**: System supports 10 concurrent participants per room.

**Test Steps**:

1. Create test meeting
2. Join from 5 different devices/browsers:
   - Desktop browser 1
   - Desktop browser 2 (different profile)
   - Mobile browser
   - Incognito desktop browser
   - Another device
3. Observe performance:
   - Video quality
   - Audio quality
   - Lag/latency
   - CPU usage: `pct exec 160 -- docker stats`

**Expected Result**:
- All participants connected
- Video quality acceptable (no freezing)
- Audio clear with no dropouts
- CPU/memory usage reasonable (<80%)

**Pass/Fail**: ☐ Pass ☐ Fail

**Performance Notes**:
```
Participants: _____
CPU Usage: _____%
Memory Usage: _____%
Video Quality: _____
Audio Quality: _____
```

---

### Test 7: Network Connectivity

**Success Criteria**: WebRTC media streams work correctly.

**Test Steps**:

1. Join meeting from external network (not on LAN)
2. Verify UDP connectivity:
   ```bash
   # From external host
   nc -zuv <public_ip> 10000
   ```
3. Check browser console for WebRTC errors
4. Verify audio/video quality

**Expected Result**:
- UDP port 10000 reachable
- No WebRTC errors in console
- Audio/video quality good

**Pass/Fail**: ☐ Pass ☐ Fail

**External IP**: `___________________`

**UDP Test Result**: ☐ Success ☐ Fail

---

## Edge Cases

### Edge Case 1: Poor Network Connectivity

**Test**: Join meeting with throttled network

**Steps**:
1. Use browser DevTools to throttle network (3G)
2. Join meeting
3. Observe behavior

**Expected**:
- Video quality degrades gracefully
- Connection maintained
- No complete failure

**Result**: ☐ Pass ☐ Fail

---

### Edge Case 2: Unsupported Browser

**Test**: Access from unsupported browser

**Steps**:
1. Try to join from old browser (if available)
2. Observe error message

**Expected**: Clear error message about browser support

**Result**: ☐ Pass ☐ Fail

---

### Edge Case 3: Connection Lost Mid-Meeting

**Test**: Network interruption handling

**Steps**:
1. Join meeting
2. Disable network for 10 seconds
3. Re-enable network
4. Observe reconnection

**Expected**: Automatic reconnection within 10 seconds

**Result**: ☐ Pass ☐ Fail

---

## Performance Validation

### Success Criteria Checklist

**SC-001**: Meeting creation in <30 seconds
- Time to create meeting: ______ seconds
- ☐ Pass (<30s) ☐ Fail (>30s)

**SC-002**: 10 concurrent participants at 720p
- Participants tested: ______
- Video quality: ______
- ☐ Pass ☐ Fail

**SC-003**: 5 simultaneous meeting rooms
- Concurrent rooms tested: ______
- Performance degradation: ☐ Yes ☐ No
- ☐ Pass ☐ Fail

**SC-004**: Screen sharing latency <2 seconds
- Measured latency: ______ seconds
- ☐ Pass (<2s) ☐ Fail (>2s)

**SC-005**: 100% recording reliability
- Recordings attempted: ______
- Recordings saved: ______
- Success rate: ______%
- ☐ Pass (100%) ☐ Fail (<100%)

**SC-006**: 95% first-meeting success rate
- Test participants: ______
- Successful without help: ______
- Success rate: ______%
- ☐ Pass (>95%) ☐ Fail (<95%)

**SC-007**: Stable for 2-hour meetings
- Meeting duration tested: ______ hours
- ☐ Pass (stable) ☐ Fail (issues)

**SC-008**: Reconnection within 10 seconds
- Tested: ☐ Yes ☐ No
- Reconnection time: ______ seconds
- ☐ Pass (<10s) ☐ Fail (>10s)

**SC-009**: SSO auth in <5 seconds
- Auth time (returning user): ______ seconds
- ☐ Pass (<5s) ☐ Fail (>5s)

**SC-010**: 99.5% uptime
- Will monitor over time
- ☐ N/A (new deployment)

---

## Security Testing

### Authentication Flow

**Test**: SSO authentication security

- [ ] HTTPS enforced (no HTTP access)
- [ ] JWT token validated correctly
- [ ] Token expiration handled
- [ ] OAuth redirect URI validated

**Pass/Fail**: ☐ Pass ☐ Fail

---

### Data Encryption

**Test**: Verify encryption

- [ ] Signaling over HTTPS (TLS)
- [ ] Media streams encrypted (check browser console for DTLS-SRTP)
- [ ] No unencrypted traffic (Wireshark/tcpdump)

**Pass/Fail**: ☐ Pass ☐ Fail

---

### Access Control

**Test**: Permission enforcement

- [ ] Anonymous users cannot access moderator controls
- [ ] Recording files not publicly accessible
- [ ] Meeting rooms not enumerable

**Pass/Fail**: ☐ Pass ☐ Fail

---

## Integration Testing

### Traefik Routing

**Test**: Reverse proxy integration

```bash
# Check routing
curl -I https://meet.viljo.se

# Expected headers
HTTP/2 200
server: nginx
x-frame-options: DENY
```

**Pass/Fail**: ☐ Pass ☐ Fail

---

### Keycloak SSO

**Test**: Identity provider integration

- [ ] Redirect to Keycloak works
- [ ] GitLab OAuth flow completes
- [ ] User attributes mapped correctly
- [ ] Token refresh works

**Pass/Fail**: ☐ Pass ☐ Fail

---

### DNS Resolution

**Test**: DNS configuration

```bash
dig meet.viljo.se +short
# Should return public IP
```

**Resolved IP**: `___________________`

**Matches public IP**: ☐ Yes ☐ No

**Pass/Fail**: ☐ Pass ☐ Fail

---

## Troubleshooting Performed

Document any issues encountered and resolutions:

### Issue 1
**Problem**:
```
_____________________________________
```

**Resolution**:
```
_____________________________________
```

---

### Issue 2
**Problem**:
```
_____________________________________
```

**Resolution**:
```
_____________________________________
```

---

## Test Summary

**Total Tests**: 13 core tests + 3 edge cases + 3 integrations = 19 tests

**Passed**: ______ / 19

**Failed**: ______ / 19

**Success Rate**: ______%

**Overall Status**: ☐ Ready for Production ☐ Issues Need Resolution

---

## Sign-Off

**Tested By**: _______________________

**Test Date**: _______________________

**Environment**: Production (meet.viljo.se)

**Deployment Approved**: ☐ Yes ☐ No

**Notes**:
```
_____________________________________
_____________________________________
_____________________________________
_____________________________________
```

---

## Next Steps

If tests pass:
- [ ] Update documentation with any findings
- [ ] Announce service availability to users
- [ ] Set up monitoring alerts
- [ ] Schedule follow-up review in 1 week

If tests fail:
- [ ] Document all failures in detail
- [ ] Identify root causes
- [ ] Create remediation plan
- [ ] Re-test after fixes
