import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {RtcTokenBuilder, RtcRole} from "agora-token";
import * as logger from "firebase-functions/logger";

admin.initializeApp();

export const generateToken = onCall(
  {region: "asia-southeast1"},
  async (request) => {
    try {
      const channelName = request.data.channelName;
      if (!channelName) {
        throw new HttpsError(
          "invalid-argument",
          "Channel name is required"
        );
      }

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

      return {token};
    } catch (error) {
      logger.error("Error generating token:", error);
      throw new HttpsError(
        "internal",
        "Failed to generate token",
        error
      );
    }
  }
);
