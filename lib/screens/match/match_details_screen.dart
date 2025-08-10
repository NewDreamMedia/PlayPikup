import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:tennis_connect/models/match_model.dart';
import 'package:tennis_connect/models/user_model.dart';
import 'package:tennis_connect/services/match_service.dart';
import 'package:tennis_connect/services/auth_service.dart';
import 'package:tennis_connect/providers/user_provider.dart';
import 'package:tennis_connect/constants/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class MatchDetailsScreen extends StatefulWidget {
  final MatchModel match;
  final double currentUserDistance;

  const MatchDetailsScreen({
    super.key,
    required this.match,
    required this.currentUserDistance,
  });

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {
  final MatchService _matchService = MatchService();
  final TextEditingController _inviteCodeController = TextEditingController();
  
  bool _isJoining = false;
  bool _hasJoined = false;
  List<UserModel> _participants = [];
  bool _isLoadingParticipants = false;

  @override
  void initState() {
    super.initState();
    _checkIfJoined();
    _loadParticipants();
  }

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  void _checkIfJoined() {
    final userId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    if (userId != null) {
      setState(() {
        _hasJoined = widget.match.playerIds.contains(userId);
      });
    }
  }

  Future<void> _loadParticipants() async {
    setState(() {
      _isLoadingParticipants = true;
    });

    try {
      final participants = <UserModel>[];
      for (final playerId in widget.match.playerIds) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(playerId)
            .get();
        if (doc.exists) {
          participants.add(UserModel.fromFirestore(doc));
        }
      }
      
      setState(() {
        _participants = participants;
        _isLoadingParticipants = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingParticipants = false;
      });
    }
  }

  Future<void> _joinMatch({String? inviteCode}) async {
    final user = Provider.of<UserProvider>(context, listen: false).currentUser;
    final authService = Provider.of<AuthService>(context, listen: false);
    
    if (user == null || authService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to join matches')),
      );
      return;
    }

    // Validate skill level
    if (!widget.match.canJoinBySkill(user.ntrpRating)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Your skill level (${user.ntrpRating}) is outside the required range '
            '(${widget.match.minNtrpRating} - ${widget.match.maxNtrpRating})',
          ),
        ),
      );
      return;
    }

    // Validate invite code for private matches
    if (!widget.match.isPublic && inviteCode != widget.match.inviteCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid invite code')),
      );
      return;
    }

    setState(() {
      _isJoining = true;
    });

    try {
      await _matchService.joinMatch(widget.match.id, authService.currentUser!.uid);
      
      setState(() {
        _hasJoined = true;
        _isJoining = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully joined the match!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Reload participants
      _loadParticipants();
      
      // TODO: Send notification to match creator
      
    } catch (e) {
      setState(() {
        _isJoining = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining match: ${e.toString()}')),
      );
    }
  }

  void _showJoinConfirmation() {
    if (!widget.match.isPublic) {
      _showInviteCodeDialog();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Match?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to join this match?'),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.calendar_today, DateFormat('EEE, MMM d').format(widget.match.matchDate)),
            _buildInfoRow(Icons.access_time, widget.match.matchTime),
            _buildInfoRow(Icons.location_on, widget.match.courtName),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _joinMatch();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            child: const Text('Join Match'),
          ),
        ],
      ),
    );
  }

  void _showInviteCodeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Invite Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This is a private match. Please enter the invite code to join.'),
            const SizedBox(height: 16),
            TextField(
              controller: _inviteCodeController,
              decoration: const InputDecoration(
                labelText: 'Invite Code',
                border: OutlineInputBorder(),
                hintText: 'e.g., ABC123',
              ),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                LengthLimitingTextInputFormatter(6),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = _inviteCodeController.text.trim();
              if (code.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter an invite code')),
                );
                return;
              }
              Navigator.pop(context);
              _joinMatch(inviteCode: code);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            child: const Text('Join Match'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCreator = widget.match.creatorId == 
        Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    final canJoin = !_hasJoined && !widget.match.isFull && widget.match.isUpcoming;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with Hero Image
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primaryGreen,
                          AppColors.primaryGreen.withOpacity(0.8),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    widget.match.matchType == MatchType.singles
                                        ? Icons.person
                                        : Icons.people,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.match.matchType == MatchType.singles ? 'Singles' : 'Doubles',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                widget.match.matchFormat.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          DateFormat('EEEE, MMMM d').format(widget.match.matchDate),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.match.matchTime,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Status Card
                _buildStatusCard(isCreator, canJoin),
                
                const SizedBox(height: 16),
                
                // Match Details Card
                _buildDetailsCard(),
                
                const SizedBox(height: 16),
                
                // Creator & Participants Card
                _buildParticipantsCard(),
                
                const SizedBox(height: 16),
                
                // Court Information Card
                _buildCourtCard(),
                
                if (widget.match.notes != null && widget.match.notes!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildNotesCard(),
                ],
                
                if (widget.match.subNeeded) ...[
                  const SizedBox(height: 16),
                  _buildSubstituteCard(),
                ],
                
                const SizedBox(height: 80), // Space for FAB
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: canJoin
          ? FloatingActionButton.extended(
              onPressed: _isJoining ? null : _showJoinConfirmation,
              backgroundColor: AppColors.primaryGreen,
              icon: _isJoining
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.add),
              label: Text(_isJoining ? 'Joining...' : 'Join Match'),
            )
          : null,
    );
  }

  Widget _buildStatusCard(bool isCreator, bool canJoin) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (_hasJoined) {
      statusColor = Colors.green;
      statusText = "You're in this match!";
      statusIcon = Icons.check_circle;
    } else if (widget.match.isFull) {
      statusColor = Colors.red;
      statusText = 'Match is full';
      statusIcon = Icons.block;
    } else if (!widget.match.isUpcoming) {
      statusColor = Colors.grey;
      statusText = 'Match has ended';
      statusIcon = Icons.history;
    } else {
      statusColor = AppColors.primaryGreen;
      statusText = '${widget.match.spotsAvailable} ${widget.match.spotsAvailable == 1 ? "spot" : "spots"} available';
      statusIcon = Icons.person_add;
    }

    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (canJoin)
                    Text(
                      widget.match.isPublic 
                          ? 'Public match - anyone can join'
                          : 'Private match - invite code required',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (isCreator)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.blue),
                    SizedBox(width: 4),
                    Text(
                      'Creator',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Match Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              Icons.sports_tennis,
              'Format',
              widget.match.matchFormat.displayName,
            ),
            const Divider(),
            _buildDetailRow(
              Icons.timeline,
              'Skill Range',
              'NTRP ${widget.match.minNtrpRating.toStringAsFixed(1)} - ${widget.match.maxNtrpRating.toStringAsFixed(1)}',
            ),
            const Divider(),
            _buildDetailRow(
              Icons.timer,
              'Duration',
              '${widget.match.duration} minutes',
            ),
            if (!widget.match.isPublic) ...[
              const Divider(),
              _buildDetailRow(
                Icons.vpn_key,
                'Invite Code',
                widget.match.inviteCode ?? 'N/A',
                trailing: IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.match.inviteCode ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite code copied to clipboard')),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Players',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${widget.match.playerIds.length}/${widget.match.matchType == MatchType.singles ? 2 : 4}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_isLoadingParticipants)
              const Center(child: CircularProgressIndicator())
            else ...[
              // Creator
              _buildPlayerTile(
                name: widget.match.creatorName,
                subtitle: 'Match Creator',
                isCreator: true,
                participant: _participants.firstWhere(
                  (p) => p.id == widget.match.creatorId,
                  orElse: () => UserModel(
                    id: widget.match.creatorId,
                    email: '',
                    displayName: widget.match.creatorName,
                    ntrpRating: 3.5,
                    playingStyle: '',
                    preferredCourtSurfaces: [],
                    availability: {},
                    preferredPlayingTimes: [],
                    city: '',
                    state: '',
                    location: const GeoPoint(0, 0),
                    createdAt: DateTime.now(),
                    lastActive: DateTime.now(),
                  ),
                ),
              ),
              
              // Other participants
              ..._participants
                  .where((p) => p.id != widget.match.creatorId)
                  .map((participant) => _buildPlayerTile(
                        name: participant.displayName,
                        subtitle: 'NTRP ${participant.ntrpRating}',
                        participant: participant,
                      )),
              
              // Empty spots
              ...List.generate(
                widget.match.spotsAvailable,
                (index) => _buildEmptyPlayerTile(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerTile({
    required String name,
    required String subtitle,
    bool isCreator = false,
    UserModel? participant,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isCreator ? Colors.blue : AppColors.primaryGreen,
        backgroundImage: participant?.photoUrl != null
            ? CachedNetworkImageProvider(participant!.photoUrl!)
            : null,
        child: participant?.photoUrl == null
            ? Text(
                name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(subtitle),
      trailing: isCreator
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Creator',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : participant != null
              ? Text(
                  participant.playingStyle.replaceAll('-', ' ').toUpperCase(),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                )
              : null,
      onTap: participant != null
          ? () {
              // TODO: Navigate to player profile
            }
          : null,
    );
  }

  Widget _buildEmptyPlayerTile() {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey[300],
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      title: Text(
        'Open Spot',
        style: TextStyle(color: Colors.grey[600]),
      ),
      subtitle: Text(
        'Waiting for player',
        style: TextStyle(color: Colors.grey[500], fontSize: 12),
      ),
    );
  }

  Widget _buildCourtCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Court Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: AppColors.primaryGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.match.courtName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.match.courtAddress,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.directions_car, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.currentUserDistance.toStringAsFixed(1)} miles away',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final url = Uri.parse(
                    'https://www.google.com/maps/search/?api=1&query='
                    '${widget.match.courtLocation.latitude},'
                    '${widget.match.courtLocation.longitude}',
                  );
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                icon: const Icon(Icons.map),
                label: const Text('Get Directions'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  side: const BorderSide(color: AppColors.primaryGreen),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notes, color: Colors.grey[700]),
                const SizedBox(width: 8),
                const Text(
                  'Additional Notes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.match.notes!,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
  
  Widget _buildSubstituteCard() {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_search,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Substitute Needed',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.match.subNeededReason != null) ...[
              const SizedBox(height: 12),
              Text(
                widget.match.subNeededReason!,
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'This match needs a substitute player. Join now to help complete the match!',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}