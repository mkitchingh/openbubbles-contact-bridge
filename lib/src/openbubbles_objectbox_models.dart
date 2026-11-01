import 'dart:typed_data';

import 'package:objectbox/objectbox.dart';

// Minimal persistence models matching the public OpenBubbles 1.15.0 ObjectBox
// schema. UI and messaging behavior is intentionally absent from the bridge.

class Attachment {
  dynamic id, originalROWID, guid, uti, mimeType, isOutgoing, transferName,
      totalBytes, height, width, webUrl, dbMetadata, hasLivePhoto, ckRecordId;
  final message = ToOne<Message>();
  Attachment({this.id, this.originalROWID, this.guid, this.uti, this.mimeType,
      this.isOutgoing, this.transferName, this.totalBytes, this.height,
      this.width, this.webUrl, this.dbMetadata, this.hasLivePhoto,
      this.ckRecordId});
}

class Chat {
  dynamic id, guid, chatIdentifier, isArchived, muteType, muteArgs, isPinned,
      hasUnreadMessage, dbOnlyLatestMessageDate, title, displayName,
      customAvatarPath, pinIndex, autoSendReadReceipts,
      autoSendTypingIndicators, textFieldText, textFieldAttachments,
      dateDeleted, style, lockChatName, lockChatIcon, lastReadMessageGuid,
      groupVersion, usingHandle, apnTitle, isRpSms, guidRefs, telephonyId,
      textFieldAnnotations, shareZenMode, notifsSilenced, dateNotifiedAnyways,
      zenModeIsShared, senderIsKnown, isRoutingStub, transcriptPosterPath,
      transcriptBackgroundVersion, cloudData, ckRecordId, ckSyncState,
      photoAttachmentGuid, cloudGuid;
  final handles = ToMany<Handle>();
  final messages = ToMany<Message>();
  Chat({this.id, this.guid, this.chatIdentifier, this.isArchived, this.muteType,
      this.muteArgs, this.isPinned, this.hasUnreadMessage,
      this.dbOnlyLatestMessageDate, this.title, this.displayName,
      this.customAvatarPath, this.pinIndex, this.autoSendReadReceipts,
      this.autoSendTypingIndicators, this.textFieldText,
      this.textFieldAttachments, this.dateDeleted, this.style,
      this.lockChatName, this.lockChatIcon, this.lastReadMessageGuid,
      this.groupVersion, this.usingHandle, this.apnTitle, this.isRpSms,
      this.guidRefs, this.telephonyId, this.textFieldAnnotations,
      this.shareZenMode, this.notifsSilenced, this.dateNotifiedAnyways,
      this.zenModeIsShared, this.senderIsKnown, this.isRoutingStub,
      this.transcriptPosterPath, this.transcriptBackgroundVersion,
      this.cloudData, this.ckRecordId, this.ckSyncState,
      this.photoAttachmentGuid, this.cloudGuid});
}

class FCMData {
  dynamic id, projectID, storageBucket, apiKey, firebaseURL, clientID,
      applicationID;
  FCMData({this.id, this.projectID, this.storageBucket, this.apiKey,
      this.firebaseURL, this.clientID, this.applicationID});
}

class Handle {
  dynamic id, originalROWID, address, country, color, defaultPhone,
      defaultEmail, formattedAddress, uniqueAddressAndService, service,
      posterPath, blocked;
  final contactRelation = ToOne<Contact>();
  Handle({this.id, this.originalROWID, this.address = '', this.country,
      this.color, this.defaultPhone, this.defaultEmail, this.formattedAddress,
      this.uniqueAddressAndService = '', this.service = 'iMessage',
      this.posterPath, this.blocked = false});
}

class ThemeEntry {
  dynamic id, themeId, name, isFont, dbColor, fontSize, fontWeight;
  final themeObject = ToOne<ThemeObject>();
  ThemeEntry({this.id, this.themeId, this.name, this.isFont, this.dbColor,
      this.fontSize, this.fontWeight});
}

class Message {
  dynamic id, originalROWID, guid, handleId, otherHandle, text, subject,
      country, error, dateCreated, dateRead, dateDelivered, isFromMe,
      hasDdResults, datePlayed, itemType, groupTitle, groupActionType,
      balloonBundleId, associatedMessageGuid, associatedMessagePart,
      associatedMessageType, expressiveSendStyleId, hasAttachments,
      hasReactions, dateDeleted, threadOriginatorGuid, threadOriginatorPart,
      hasApplePayloadData, dateEdited, wasDeliveredQuietly,
      didNotifyRecipient, isBookmarked, hasBeenForwarded, stagingGuid,
      amkSessionId, verificationFailed, sendingServiceId,
      associatedMessageEmoji, dateScheduled, ckRecordId, dbAttributedBody,
      dbMessageSummaryInfo, dbPayloadData, dbMetadata, bigEmoji, ckSyncState,
      isDelivered;
  final chat = ToOne<Chat>();
  final dbAttachments = ToMany<Attachment>();
  Message({this.id, this.originalROWID, this.guid, this.handleId,
      this.otherHandle, this.text, this.subject, this.country, this.error,
      this.dateCreated, this.dateRead, this.dateDelivered, this.isFromMe,
      this.hasDdResults, this.datePlayed, this.itemType, this.groupTitle,
      this.groupActionType, this.balloonBundleId, this.associatedMessageGuid,
      this.associatedMessagePart, this.associatedMessageType,
      this.expressiveSendStyleId, this.hasAttachments, this.hasReactions,
      this.dateDeleted, this.threadOriginatorGuid, this.threadOriginatorPart,
      this.hasApplePayloadData, this.dateEdited, this.wasDeliveredQuietly,
      this.didNotifyRecipient, this.isBookmarked, this.hasBeenForwarded,
      this.stagingGuid, this.amkSessionId, this.verificationFailed,
      this.sendingServiceId, this.associatedMessageEmoji, this.dateScheduled,
      this.ckRecordId, this.dbAttributedBody, this.dbMessageSummaryInfo,
      this.dbPayloadData, this.dbMetadata, this.bigEmoji, this.ckSyncState,
      this.isDelivered});
}

class ThemeObject {
  dynamic id, name, selectedLightTheme, selectedDarkTheme, gradientBg,
      previousLightTheme, previousDarkTheme;
  final themeEntries = ToMany<ThemeEntry>();
  ThemeObject({this.id, this.name, this.selectedLightTheme,
      this.selectedDarkTheme, this.gradientBg, this.previousLightTheme,
      this.previousDarkTheme});
}

class ThemeStruct {
  dynamic id, name, gradientBg, dbThemeData, googleFont;
  ThemeStruct({this.id, this.name, this.gradientBg, this.dbThemeData,
      this.googleFont});
}

class Contact {
  int? dbId;
  String id;
  String displayName;
  List<String> phones;
  List<String> emails;
  Uint8List? avatar;
  String? dbStructuredName;
  bool isShared;
  bool isDismissed;
  String? posterPath;
  Contact({this.dbId, this.id = '', this.displayName = '',
      this.phones = const <String>[], this.emails = const <String>[],
      this.avatar, this.dbStructuredName, this.isShared = false,
      this.isDismissed = false, this.posterPath});
}
