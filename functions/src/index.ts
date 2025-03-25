import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import {RtcTokenBuilder, RtcRole} from "agora-token";
import * as logger from "firebase-functions/logger";

admin.initializeApp();

export const generateToken = onCall(
  {region: "asia-southeast1"},
  async (request) => {
    try {
      const channelName = request.data.channelName;
      const patientId = request.data.patientId;

      if (!channelName || !patientId) {
        throw new HttpsError(
          "invalid-argument",
          "Channel name and patient ID are required"
        );
      }

      const userSnapshot = await admin.database()
        .ref(`administrator/users/${patientId}`)
        .once("value");

      if (!userSnapshot.exists()) {
        throw new HttpsError(
          "not-found",
          "Patient not found"
        );
      }

      const userData = userSnapshot.val();
      const fcmToken = userData?.fcmToken;

      const appID = "3a7bf343ec50426697144687e52dfac6";
      const appCertificate = "b7dd19d277ca47e0b7229f6db33b3a40";
      const uid = 0;
      const expirationTimeInSeconds = 3600;
      const currentTimestamp = Math.floor(Date.now() / 1000);
      const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

      const token = RtcTokenBuilder.buildTokenWithUid(
        appID,
        appCertificate,
        channelName,
        uid,
        RtcRole.PUBLISHER,
        privilegeExpiredTs,
        privilegeExpiredTs
      );

      await admin.database()
        .ref(`agoraChannels/${channelName}`)
        .update({
          token: token,
          status: "connecting",
          lastUpdated: admin.database.ServerValue.TIMESTAMP,
        });

      if (fcmToken) {
        await admin.messaging().send({
          token: fcmToken,
          notification: {
            title: "Incoming Call",
            body: "A doctor is calling you",
          },
          data: {
            type: "call",
            channelId: channelName,
            doctorId: request.auth?.uid || "",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          android: {
            priority: "high" as const,
          },
        });
      }

      return {
        token,
        channelName,
        timestamp: currentTimestamp,
      };
    } catch (error) {
      logger.error("Error generating token:", error);

      if (request.data.channelName) {
        try {
          await admin.database()
            .ref(`agoraChannels/${request.data.channelName}`)
            .remove();
        } catch (cleanupError) {
          logger.error("Error cleaning up channel:", cleanupError);
        }
      }

      throw new HttpsError(
        "internal",
        "Failed to generate token",
        error,
      );
    }
  }
);

export const cleanupStaleChannels = onSchedule({
  schedule: "every 24 hours",
  region: "asia-southeast1",
}, async (): Promise<void> => {
  const oneHourAgo = Date.now() - (60 * 60 * 1000);

  const staleChannelsRef = admin.database()
    .ref("agoraChannels")
    .orderByChild("timestamp")
    .endAt(oneHourAgo);

  const snapshot = await staleChannelsRef.once("value");
  const updates: { [key: string]: null } = {};

  snapshot.forEach((childSnapshot) => {
    updates[childSnapshot.key] = null;
  });

  if (Object.keys(updates).length > 0) {
    await admin.database().ref("agoraChannels").update(updates);
    logger.info(`Cleaned up ${Object.keys(updates).length} stale channels`);
  }
});

