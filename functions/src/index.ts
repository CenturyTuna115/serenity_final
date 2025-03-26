import {onRequest} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {RtcTokenBuilder, RtcRole} from "agora-token";
import * as logger from "firebase-functions/logger";

admin.initializeApp();

/**
 * Helper to generate a random channel name if not provided.
 * @return {string} A randomly generated channel name with
 * timestamp and random suffix
 */
function generateRandomChannelName(): string {
  const randomSuffix = Math.random().toString(36).substring(2, 10);
  return `channel_${Date.now()}_${randomSuffix}`;
}

export const generateToken = onRequest(
  {region: "asia-southeast1"},
  async (req, res): Promise<void> => {
    // Only allow POST requests
    if (req.method !== "POST") {
      res.status(405).json({error: "Method Not Allowed. Use POST."});
      return;
    }

    try {
      // Parse JSON body
      const {channelName, patientId, callerName} = req.body;

      if (!patientId) {
        res.status(400).json({error: "Missing required field: patientId"});
        return;
      }
      if (!callerName) {
        res.status(400).json({error: "Missing required field: callerName"});
        return;
      }

      // Generate channel name if not provided
      const finalChannelName = channelName || generateRandomChannelName();

      // 1) Fetch the patient's data from RTDB to get FCM token
      const userSnapshot = await admin
        .database()
        .ref(`administrator/users/${patientId}`)
        .once("value");

      if (!userSnapshot.exists()) {
        res.status(404).json({error: "Patient not found."});
        return;
      }

      const userData = userSnapshot.val();
      const fcmToken = userData?.fcmToken;
      // If there's no fcmToken, we can't send a push
      if (!fcmToken) {
        logger.warn(`User ${patientId} has no FCM token stored.`);
      }

      // 2) Generate the Agora token
      const appID = "3a7bf343ec50426697144687e52dfac6";
      const appCertificate = "b7dd19d277ca47e0b7229f6db33b3a40";
      const uid = 0; // or any other integer UID
      const expirationTimeInSeconds = 3600; // 1 hour
      const currentTimestampSec = Math.floor(Date.now() / 1000);
      const privilegeExpiredTs = currentTimestampSec + expirationTimeInSeconds;

      let token: string;
      try {
        token = RtcTokenBuilder.buildTokenWithUid(
          appID,
          appCertificate,
          finalChannelName,
          uid,
          RtcRole.PUBLISHER,
          privilegeExpiredTs,
          privilegeExpiredTs
        );
        if (!token) {
          throw new Error("Token generation returned empty.");
        }
      } catch (error) {
        logger.error("Token generation failed:", error);
        res.status(500).json({error: "Failed to generate token."});
        return;
      }

      // 3) Write data to RTDB (optional, but often helpful)
      try {
        await admin
          .database()
          .ref(`agoraChannels/${finalChannelName}`)
          .update({
            channelName: finalChannelName,
            patientId,
            callerName, // store the caller's name
            token,
            status: "connecting",
            timestamp: admin.database.ServerValue.TIMESTAMP,
            lastUpdated: admin.database.ServerValue.TIMESTAMP,
          });
      } catch (error) {
        logger.error("Failed to update channel data:", error);
        res.status(500).json({error: "Failed to update channel."});
        return;
      }

      // 4) Send a push notification if we have an FCM token
      if (fcmToken) {
        // Customize the title/body to display the caller's name
        const notificationPayload = {
          token: fcmToken,
          notification: {
            title: "Incoming Call",
            body: `${callerName} is calling you!`,
          },
          data: {
            type: "call",
            channelId: finalChannelName,
            callerName: callerName,
            // In your Flutter code, you'll parse this data
            // and show a local notification with Accept/Decline.
          },
          android: {
            priority: "high" as const,
          },
          // For iOS, you might also specify apns payload, etc.
        };

        try {
          await admin.messaging().send(notificationPayload);
        } catch (error) {
          logger.error("FCM send error:", error);
          // Not a fatal error for the function, but we log it.
        }
      }

      // 5) Return the token/channel to the caller
      res.status(200).json({
        token,
        channelName: finalChannelName,
        callerName,
        timestamp: currentTimestampSec,
      });
      return;
    } catch (error) {
      logger.error("Error generating token:", error);
      res.status(500).json({error: "Internal server error."});
      return;
    }
  }
);
