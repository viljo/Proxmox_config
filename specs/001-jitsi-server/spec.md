# Feature Specification: Jitsi Meet Video Conferencing Server

**Feature Branch**: `001-jitsi-server`
**Created**: 2025-10-27
**Status**: Draft
**Input**: User description: "jitsi server container"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Basic Video Meeting Creation (Priority: P1)

Team members need to quickly start video meetings without requiring accounts or complex setup. Anyone with the meeting URL can join instantly.

**Why this priority**: This is the core value proposition - instant, accessible video conferencing. Without this, the feature has no value.

**Independent Test**: Can be fully tested by having a user create a meeting room and another user join using the URL, demonstrating basic peer-to-peer video communication.

**Acceptance Scenarios**:

1. **Given** a user accesses the Jitsi server URL, **When** they enter a meeting room name, **Then** they are immediately placed in that room with audio and video capabilities
2. **Given** a meeting room is active, **When** another user enters the same room name, **Then** they join the existing meeting and can see/hear other participants
3. **Given** users are in a meeting, **When** they share the meeting URL with others, **Then** new participants can join by clicking the URL without authentication

---

### User Story 2 - Screen Sharing and Collaboration (Priority: P2)

Meeting participants need to share their screens to present content, review documents, or provide remote assistance during video calls.

**Why this priority**: Screen sharing is essential for productive business meetings and collaboration, making it the most important feature after basic video.

**Independent Test**: Can be tested by one participant initiating screen share and others confirming they can view the shared content clearly.

**Acceptance Scenarios**:

1. **Given** a user is in an active meeting, **When** they click the screen share button, **Then** they can select a window or entire screen to share with all participants
2. **Given** a user is sharing their screen, **When** other participants view the meeting, **Then** they see the shared screen content in real-time with minimal lag
3. **Given** a user is sharing their screen, **When** they stop sharing, **Then** all participants return to seeing the standard video grid layout

---

### User Story 3 - Meeting Recording (Priority: P3)

Meeting hosts need to record video conferences for documentation, review, or for participants who couldn't attend live.

**Why this priority**: Recording is valuable for knowledge retention and asynchronous participation but is not critical for basic meeting functionality.

**Independent Test**: Can be tested by starting a meeting, enabling recording, and verifying the saved recording file is accessible and playable after the meeting ends.

**Acceptance Scenarios**:

1. **Given** a user is hosting a meeting, **When** they start recording, **Then** the entire meeting including audio, video, and screen shares is captured
2. **Given** a meeting is being recorded, **When** participants join or leave, **Then** the recording continues uninterrupted
3. **Given** a recording has been completed, **When** the meeting ends, **Then** the recording file is saved to accessible storage with proper naming (date, time, room name)

---

### User Story 4 - SSO Integration with GitLab (Priority: P4)

Organization users want to authenticate using their existing GitLab.com credentials via the Keycloak SSO infrastructure for consistent identity management.

**Why this priority**: While desirable for security and user management, meetings can function without SSO initially using anonymous access.

**Independent Test**: Can be tested by accessing the Jitsi server, being redirected to Keycloak/GitLab for authentication, and successfully joining a meeting with authenticated identity.

**Acceptance Scenarios**:

1. **Given** SSO is enabled, **When** a user accesses the Jitsi server, **Then** they are redirected to Keycloak for GitLab authentication
2. **Given** a user completes GitLab OAuth authentication, **When** they return to Jitsi, **Then** their display name is automatically populated from their GitLab profile
3. **Given** an authenticated user creates a meeting, **When** other authenticated users join, **Then** participant names are displayed from their GitLab profiles

---

### Edge Cases

- What happens when network connectivity is poor or unstable during a meeting?
- How does the system handle meetings with more than 10 participants (scaling limits)?
- What happens when a user attempts to join a meeting from an unsupported browser?
- How does the system behave when storage for recordings approaches capacity?
- What happens when a user loses internet connection mid-meeting?
- How are recordings handled if the meeting ends unexpectedly (server crash, power loss)?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide browser-based video conferencing without requiring client software installation
- **FR-002**: System MUST support real-time audio and video communication between multiple participants
- **FR-003**: Users MUST be able to create meeting rooms by simply entering a room name
- **FR-004**: System MUST allow participants to join meetings using a direct URL without authentication (anonymous access)
- **FR-005**: System MUST support screen sharing functionality for all meeting participants
- **FR-006**: System MUST provide audio/video controls (mute, camera off, volume adjustment) for participants
- **FR-007**: System MUST show participant list with names (or anonymous identifiers) in active meetings
- **FR-008**: System MUST support meeting recording functionality with recordings stored on the Proxmox host filesystem and bind-mounted to the container for reliable, expandable storage
- **FR-009**: System MUST integrate with existing Keycloak SSO infrastructure for optional authenticated access
- **FR-010**: System MUST run as a containerized service in the Proxmox LXC infrastructure
- **FR-011**: System MUST be accessible via HTTPS through the existing Traefik reverse proxy
- **FR-012**: System MUST support simultaneous meetings in different rooms without interference
- **FR-013**: System MUST provide chat functionality for text communication during meetings
- **FR-014**: System MUST implement a moderator role model where authenticated users (via SSO) automatically receive moderator privileges, while anonymous participants join as guests with limited capabilities. Moderators can mute, remove, or grant/revoke moderator status to other participants
- **FR-015**: System MUST persist meeting configurations and settings across container restarts

### Key Entities

- **Meeting Room**: A virtual space identified by a unique name where participants gather for video conferencing. Attributes include room name, creation time, participant count, active status, recording status.
- **Participant**: An individual user in a meeting. Attributes include display name (from SSO or self-entered), audio/video status, moderator status, join time.
- **Recording**: A captured video file of a meeting. Attributes include meeting room name, timestamp, duration, file size, file location.
- **Session**: Represents a participant's connection to a meeting room. Attributes include connection status, network quality, joined timestamp, audio/video stream states.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can create and join meetings in under 30 seconds from accessing the URL
- **SC-002**: System supports at least 10 concurrent participants per meeting room with acceptable video quality (720p minimum)
- **SC-003**: System maintains at least 5 simultaneous meeting rooms without performance degradation
- **SC-004**: Screen sharing displays with less than 2 seconds latency for all participants
- **SC-005**: Meeting recordings are successfully saved with 100% reliability when recording is active
- **SC-006**: 95% of users successfully complete their first meeting without technical support
- **SC-007**: Audio and video quality remains stable for meetings lasting up to 2 hours
- **SC-008**: System recovers gracefully from network interruptions with automatic reconnection within 10 seconds
- **SC-009**: SSO authentication completes in under 5 seconds for returning users
- **SC-010**: System is accessible and functional 99.5% of the time (excluding planned maintenance)

## Scope & Boundaries *(mandatory)*

### In Scope

- Video conferencing infrastructure deployment
- Basic meeting room creation and management
- Audio, video, and screen sharing capabilities
- Meeting recording functionality
- Integration with existing Keycloak SSO (optional authentication path)
- Anonymous meeting access (primary path)
- Traefik reverse proxy integration
- Container deployment in Proxmox LXC environment
- Basic moderator controls for meetings
- Text chat within meetings

### Out of Scope

- Native mobile apps (browser-based mobile access is sufficient)
- Calendar integration (Google Calendar, Outlook)
- Dial-in phone number support for audio-only participants
- Advanced features like virtual backgrounds or noise cancellation
- Live streaming to external platforms (YouTube, Facebook)
- Meeting scheduling or invitation management
- User directory or contact management
- Integration with other services beyond SSO
- Custom branding beyond basic logo/title changes
- Participant limits beyond 10 users per room initially

## Assumptions & Dependencies

### Assumptions

- Users have modern web browsers with WebRTC support (Chrome, Firefox, Safari, Edge)
- Network infrastructure supports UDP traffic for optimal media streaming
- Existing Proxmox infrastructure has sufficient resources (CPU, RAM, network bandwidth)
- Users have webcams and microphones for video participation
- Proxmox host has adequate storage space for meeting recordings (bind-mounted to container)
- Authenticated users via SSO are considered trusted and granted moderator privileges
- Anonymous participants are considered guests with limited capabilities
- Meeting rooms persist for the duration of active participation (not permanent virtual rooms)

### Dependencies

- **Proxmox LXC Infrastructure**: Container hosting environment must be available and properly configured
- **Proxmox Host Storage**: Filesystem space on Proxmox host for recording storage with bind mount to container
- **Traefik Reverse Proxy**: Must be configured and operational for HTTPS access and routing
- **Keycloak SSO**: Required for authenticated access and moderator role assignment
- **Network Connectivity**: Adequate bandwidth for video streaming (minimum 2Mbps per participant recommended)
- **DNS**: Proper DNS configuration for the Jitsi server domain (e.g., meet.viljo.se)
- **SSL Certificates**: Valid SSL certificates via Traefik for secure browser access

## Non-Functional Requirements *(optional)*

### Performance

- Video quality should adapt automatically based on available bandwidth
- System should support HD video (720p) when bandwidth permits
- Audio latency should be under 200ms for acceptable real-time conversation
- System resource usage should remain stable during extended meetings

### Security

- All communication must be encrypted (HTTPS for signaling, DTLS-SRTP for media)
- Meeting rooms should support optional password protection
- Anonymous participants should have limited capabilities compared to authenticated users
- Meeting recordings should have restricted access controls

### Usability

- Interface should be intuitive for first-time users without training
- Common controls (mute, camera, screen share) should be easily accessible
- System should work across desktop and mobile browsers
- Audio/video quality indicators should be visible to participants

### Reliability

- System should gracefully handle participant connection drops and reconnections
- Recordings should not be lost due to system failures
- Meeting state should be preserved during brief network interruptions
- Container should restart automatically if it crashes

### Scalability

- Initial deployment should support 5 concurrent meeting rooms
- Architecture should allow horizontal scaling for more rooms if needed
- Recording storage should be expandable without service interruption

## Notes

- Jitsi Meet is an open-source video conferencing solution, well-suited for self-hosted deployments
- WebRTC technology ensures browser-based access without plugins
- The system will integrate with existing SSO infrastructure (GitLab.com → Keycloak → Jitsi) for authenticated access
- Anonymous access provides quickest path to value and lowest barrier to entry
- Consider bandwidth requirements: each participant needs 1-2 Mbps upload and similar download per other participant
