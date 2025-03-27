import {onRequest} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {RtcTokenBuilder, RtcRole} from "agora-token";
import * as logger from "firebase-functions/logger";

admin.initializeApp();

/**
 * Cloud Function to generate Agora token and handle call setup.
 *
 * Expected request body:
 * {
 *   "doctorId": "<doctor's ID>",
 *   "callerName": "<caller name>"
 * }
 *
 * The channel name will be created as "doctorId-userId".
 */
export const generateToken = onRequest(
  {region: "asia-southeast1"},
  async (req, res): Promise<void> => {
    // Set CORS headers for every response.
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

    // Handle preflight request.
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    // Only allow POST requests.
    if (req.method !== "POST") {
      res.status(405).json({error: "Method Not Allowed. Use POST."});
      return;
    }

    try {
      // 1. Verify Firebase ID token from the Authorization header.
      let userId: string;
      try {
        const authHeader = req.headers.authorization || "";
        const token = authHeader.split(" ")[1];
        if (!token) {
          throw new Error("Missing ID token");
        }
        const decodedToken = await admin.auth().verifyIdToken(token);
        userId = decodedToken.uid;
      } catch (error) {
        logger.error("Error verifying ID token:", error);
        res.status(401).json({error: "Invalid or missing token."});
        return;
      }

      // 2. Extract fields from request body.
      const {doctorId, callerName} = req.body;
      if (!doctorId) {
        res.status(400).json({error: "Missing required field: doctorId"});
        return;
      }
      if (!callerName) {
        res.status(400).json({error: "Missing required field: callerName"});
        return;
      }

      // 3. Determine final channel name as "doctorId-userId".
      const finalChannelName = `${doctorId}-${userId}`;

      // 4. Get Agora credentials from environment variables
      const appID = process.env.AGORA_APP_ID ||
        "3a7bf343ec50426697144687e52dfac6";
      const appCertificate = process.env.AGORA_APP_CERTIFICATE ||
        "b7dd19d277ca47e0b7229f6db33b3a40";
      const uid = 0; // Typically a numeric UID.
      const expirationTimeInSeconds = 3600; // 1 hour.
      const currentTimestampSec = Math.floor(Date.now() / 1000);
      const privilegeExpiredTs = currentTimestampSec + expirationTimeInSeconds;

      // 5. Generate Agora token
      let token: string;
      try {
        token = RtcTokenBuilder.buildTokenWithUid(
          appID,
          appCertificate,
          finalChannelName,
          uid,
          RtcRole.PUBLISHER,
          privilegeExpiredTs,
          privilegeExpiredTs,
        );
        if (!token) {
          throw new Error("Token generation returned empty.");
        }
      } catch (error) {
        const errorMessage = error instanceof Error ?
          error.message : String(error);
        logger.error("Token generation failed:", errorMessage);
        res.status(500).json({error: "Failed to generate token."});
        return;
      }

      // 6. Check if channel already exists - don't allow updates
      try {
        const channelRef = admin.database()
          .ref(`agoraChannels/${finalChannelName}`);
        const channelSnapshot = await channelRef.once("value");
        if (channelSnapshot.exists()) {
          logger.warn(`Channel already exists: ${finalChannelName}`);
          res.status(409).json({error: "Call already in progress"});
          return;
        }
        logger.info(`Creating new channel: ${finalChannelName}`);
        await channelRef.set({
          channelName: finalChannelName,
          userId,
          doctorId,
          callerName,
          token,
          status: "connecting",
          timestamp: admin.database.ServerValue.TIMESTAMP,
          lastUpdated: admin.database.ServerValue.TIMESTAMP,
        });
      } catch (error) {
        const errorMessage = error instanceof Error ?
          error.message : String(error);
        logger.error("Failed to update channel data:", errorMessage);
        res.status(500).json({error: "Failed to update channel."});
        return;
      }

      // 7. Send response with token and channel info
      res.status(200).json({
        token,
        channelName: finalChannelName,
        callerName,
        timestamp: currentTimestampSec,
      });
      return;
    } catch (error) {
      const errorMessage = error instanceof Error ?
        error.message : String(error);
      logger.error("Error generating token:", errorMessage);
      res.status(500).json({error: "Internal server error."});
      return;
    }
  }
);
