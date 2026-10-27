@RestResource(urlMapping='/InvoiceEmailService/*')
global with sharing class InvoiceEmailService {

    global class EmailResponse {
        public Boolean success;
        public String message;
    }

    @HttpPost
    global static EmailResponse sendInvoiceEmail(String toAddress, String subject, String htmlBody, String fileName, String pdfBase64) {
        EmailResponse resp = new EmailResponse();
        try {
            if (String.isBlank(toAddress)) {
                resp.success = false;
                resp.message = 'Recipient email address is required.';
                return resp;
            }

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { toAddress.trim() });
            mail.setSubject(String.isNotBlank(subject) ? subject : 'Britannia Industries - Tax Invoice');
            mail.setHtmlBody(String.isNotBlank(htmlBody) ? htmlBody : '<p>Please find attached your Tax Invoice.</p>');

            if (String.isNotBlank(pdfBase64)) {
                Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
                efa.setFileName(String.isNotBlank(fileName) ? fileName : 'Tax_Invoice.pdf');
                efa.setBody(EncodingUtil.base64Decode(pdfBase64));
                efa.setContentType('application/pdf');
                mail.setFileAttachments(new Messaging.EmailFileAttachment[] { efa });
            }

            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            if (results != null && results.size() > 0 && results[0].isSuccess()) {
                resp.success = true;
                resp.message = 'Email delivered successfully to ' + toAddress;
            } else {
                resp.success = false;
                resp.message = (results != null && results.size() > 0 && results[0].getErrors().size() > 0)
                    ? results[0].getErrors()[0].getMessage() 
                    : 'Failed to send email.';
            }
        } catch (Exception ex) {
            resp.success = false;
            resp.message = ex.getMessage();
        }
        return resp;
    }
}